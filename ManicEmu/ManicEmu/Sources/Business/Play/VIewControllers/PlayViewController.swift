//
//  PlayViewController.swift
//  ManicEmu
//
//  Created by Max on 2025/1/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import UIKit
import ManicEmuCore
import Schedule
import Haptica
import RealmSwift
import ProHUD
import IceCream
import StoreKit
import AVFoundation
#if targetEnvironment(simulator)
import MetalKit
#endif

//MARK: 主类
class PlayViewController: GameViewController {
    //游戏 业务层定义 注意和core里面定义的Game区分
    private let manicGame: Game
    private let gameFileName: String
    //默认加载的即时存档
    private var loadSaveState: GameSaveState? = nil
    //MARK: 通知定义
    private var gameControllerDidConnectNotification: Any? = nil
    private var gameControllerDidDisConnectNotification: Any? = nil
    private var keyboardDidConnectNotification: Any? = nil
    private var keyboardDidDisConnectNotification: Any? = nil
    private var sceneWillConnectNotification: Any? = nil
    private var sceneDidDisconnectNotification: Any? = nil
    private var scenewillDeactivateNotification: Any? = nil
    private var sceneDidActivateNotification: Any? = nil
    private var windowDidBecomeKeyNotification: Any? = nil
    private var membershipNotification: Any? = nil
    private var controllerMappingNotification: Any? = nil
    
    //每分钟执行一次
    private lazy var repeatTimer: Schedule.Task = {
        if let task = TaskCenter.default.tasks(forTag: String(describing: Self.self)).first {
            return task
        } else {
            let task = Plan.every(Constants.Numbers.AutoSaveGameDuration.seconds).do(queue: .global()) { [weak self] in
                guard let self = self else { return }
                //每分钟记录一次游戏时间
                self.calculatePlayTime()
                //每分钟保存一次存档
                DispatchQueue.main.async { [weak self] in
                    guard Settings.defalut.autoSaveState, let self = self else { return }
                    if self.manicGame.gameType.isLibretroType {
                        self.saveStateForLibretro(type: .autoSaveState)
                    } else {
                        self.saveState(type: .autoSaveState)
                    }
                }
            }
            TaskCenter.default.addTag(String(describing: Self.self), to: task)
            return task
        }
    }()
    //默认皮肤控制玩家1
    static var skinControllerPlayerIndex = 0 {
        didSet {
            if let currentPlayViewController = currentPlayViewController {
                currentPlayViewController.controllerView.playerIndex = skinControllerPlayerIndex
            }
        }
    }
    //游戏控制器，如果游戏在运行中则有值，没有进行游戏的时候则为nil
    static weak var currentPlayViewController: PlayViewController? = nil
    //屏幕上的功能按钮容器
    private var functionButtonContainer = FunctionButtonContainerView()
    //除了delta之外的渲染视图
    private var gameMetalView: UIView? = nil
    //3DS核心
    private var threeDSCore: ThreeDSEmulatorBridge? = nil
    //监听静音键变化
    private lazy var muteSwitchMonitor = DLTAMuteSwitchMonitor()
    
    deinit {
        Log.debug("\(String(describing: Self.self)) deinit")
        if let gameControllerDidConnectNotification = gameControllerDidConnectNotification {
            NotificationCenter.default.removeObserver(gameControllerDidConnectNotification)
        }
        if let gameControllerDidDisConnectNotification = gameControllerDidDisConnectNotification {
            NotificationCenter.default.removeObserver(gameControllerDidDisConnectNotification)
        }
        if let keyboardDidConnectNotification = keyboardDidConnectNotification {
            NotificationCenter.default.removeObserver(keyboardDidConnectNotification)
        }
        if let keyboardDidDisConnectNotification = keyboardDidDisConnectNotification {
            NotificationCenter.default.removeObserver(keyboardDidDisConnectNotification)
        }
        if let sceneWillConnectNotification = sceneWillConnectNotification {
            NotificationCenter.default.removeObserver(sceneWillConnectNotification)
        }
        if let sceneDidDisconnectNotification = sceneDidDisconnectNotification {
            NotificationCenter.default.removeObserver(sceneDidDisconnectNotification)
        }
        if let scenewillDeactivateNotification = scenewillDeactivateNotification {
            NotificationCenter.default.removeObserver(scenewillDeactivateNotification)
        }
        if let sceneDidActivateNotification = sceneDidActivateNotification {
            NotificationCenter.default.removeObserver(sceneDidActivateNotification)
        }
        if let windowDidBecomeKeyNotification = windowDidBecomeKeyNotification {
            NotificationCenter.default.removeObserver(windowDidBecomeKeyNotification)
        }
        if let membershipNotification = membershipNotification {
            NotificationCenter.default.removeObserver(membershipNotification)
        }
        if let controllerMappingNotification = controllerMappingNotification {
            NotificationCenter.default.removeObserver(controllerMappingNotification)
        }
        if SyncManager.shared.hasDownloadTask {
            UIView.makeLoadingToast(message: R.string.localizable.loadingTitle())
        }
    }
    
    //数据库变化通知
    private var gameUpdateToken: Any? = nil
    private var cheatCodeUpdateToken: Any? = nil
    private var settingsUpdateToken: Any? = nil
    
    private var lastSaveDate: Date? = nil
    private var lastLoadDate: Date? = nil
    
    private var isFullScreen = false
    
    private var lastPSPCheatCode: String = ""
    
    static func startGame(game: Game, saveState: GameSaveState? = nil) {
        if game.isRomExtsts {
            UIView.hideLoadingToast(forceHide: true)
            func showPlayView() {
                if game.isBIOSMissing() {
                    //检查是否缺失BIOS
                    topViewController(appController: true)?.present(BIOSSelectionViewController(gameType: game.gameType), animated: true)
                    return
                }
                if game.gameType == .unknown {
                    PlatformSelectionView.show(game: game)
                    return
                }                
                func launchGameByDismissOtherVC() {
                    //游戏控制器和rootVC之间存在控制器则会导致游戏卡顿异常 估计是iOS的bug，导致了Main Run Loop调度异常
                    if game.gameType.isLibretroType {
                        LibretroCore.sharedInstance().workspace = Constants.Path.Libretro
                    }
                    if let homeVC = topViewController(appController: true), homeVC is HomeViewController {
                        topViewController(appController: true)?.present(PlayViewController(game: game, saveState: saveState), animated: true)
                    } else if let homeVC = ApplicationSceneDelegate.applicationWindow?.rootViewController as? HomeViewController {
                        if let vc = homeVC.presentedViewController {
                            vc.dismiss(animated: true) {
                                topViewController(appController: true)?.present(PlayViewController(game: game, saveState: saveState), animated: true)
                            }
                        } else {
                            topViewController(appController: true)?.present(PlayViewController(game: game, saveState: saveState), animated: true)
                        }
                    } else {
                        topViewController(appController: true)?.present(PlayViewController(game: game, saveState: saveState), animated: true)
                    }
                }
                if game.gameType == ._3ds, !UIDevice.current.hasA11ProcessorOrBetter, !UserDefaults.standard.bool(forKey: Constants.DefaultKey.HasShow3DSNotSupportAlert) {
                    UIView.makeAlert(title: R.string.localizable.threeDSNoSupportDeviceTitle(), detail: R.string.localizable.threeDSNoSupportDeviceDetail(), confirmTitle: R.string.localizable.gameSaveContinue(), confirmAction: {
                        UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShow3DSNotSupportAlert)
                        launchGameByDismissOtherVC()
                    })
                } else {
                    launchGameByDismissOtherVC()
                }
            }
            if game.gameType == ._3ds, !UserDefaults.standard.bool(forKey: Constants.DefaultKey.HasShow3DSPlayAlert) {
                UIView.makeAlert(title: R.string.localizable.threeDSBetaAlertTitle(),
                                 detail: R.string.localizable.threeDSBetaAlertDetail(),
                                 detailAlignment: .left,
                                 cancelTitle: R.string.localizable.confirmTitle(), cancelAction: {
                    UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShow3DSPlayAlert)
                    showPlayView()
                }, hideAction: {
                    UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShow3DSPlayAlert)
                });
            } else if game.gameType == .ss, !UserDefaults.standard.bool(forKey: Constants.DefaultKey.HasShowSSPlayAlert), game.isBIOSMissing(required: false), game.defaultCore == 1 {
                UIView.makeAlert(title: R.string.localizable.saturnBiosAlertTitle(),
                                 detail: R.string.localizable.saturnBiosAlertDetail(),
                                 detailAlignment: .left,
                                 cancelTitle: R.string.localizable.startGameWithoutBiosTitle(),
                                 confirmTitle: R.string.localizable.biosAddTitle(), cancelAction: {
                    UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShowSSPlayAlert)
                    showPlayView()
                }, confirmAction: {
                    UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShowSSPlayAlert)
                    topViewController(appController: true)?.present(BIOSSelectionViewController(gameType: .ss), animated: true)
                }, hideAction: {
                    UserDefaults.standard.set(true, forKey: Constants.DefaultKey.HasShowSSPlayAlert)
                });
            }  else {
                showPlayView()
            }
        } else {
            UIView.makeLoading()
            SyncManager.isiCloudFileExist(localFilePath: game.romUrl.path) { fileExists in
                UIView.hideLoading()
                if fileExists {
                    //rom存在iCloud上
                    //rom还没离线下来
                    UIView.makeLoadingToast(message: R.string.localizable.loadingTitle())
                    SyncManager.download(localFilePath: game.romUrl.path) { error in
                        UIView.hideLoadingToast()
                        UIView.makeToast(message: R.string.localizable.loadRomSuccess(game.aliasName ?? game.name))
                    }
                } else {
                    UIView.makeToast(message: R.string.localizable.loadGameErrorRomNotExist())
                }
            }
        }
    }
    
    //MARK: 生命周期
    private init(game: Game, saveState: GameSaveState? = nil) {
        manicGame = game
        gameFileName = game.fileName
        super.init()
        Log.debug("\(String(describing: Self.self)) init")
        prefersVolumeEnable = manicGame.volume
        loadSaveState = saveState
        modalPresentationStyle = .fullScreen
        delegate = self
        self.game = ManicEmuCore.Game(fileURL: game.romUrl, type: game.gameType)
        
        //MARK: 通知监听
        ///管理控制外设的连接
        gameControllerDidConnectNotification = NotificationCenter.default.addObserver(forName: .externalGameControllerDidConnect, object: nil, queue: .main) { [weak self] notification in
            //手柄连接
            self?.updateExternalGameController()
            self?.updateSkin()
        }
        gameControllerDidDisConnectNotification = NotificationCenter.default.addObserver(forName: .externalGameControllerDidDisconnect, object: nil, queue: .main) { [weak self] notification in
            //手柄断开连接
            if ExternalGameControllerUtils.shared.linkedControllers.count == 0 {
                self?.updateSkin()
            }
        }
        keyboardDidConnectNotification = NotificationCenter.default.addObserver(forName: .externalKeyboardDidConnect, object: nil, queue: .main) { [weak self] notification in
            //键盘连接
            self?.updateExternalGameController()
            self?.updateSkin()
        }
        keyboardDidDisConnectNotification = NotificationCenter.default.addObserver(forName: .externalKeyboardDidDisconnect, object: nil, queue: .main) { [weak self] notification in
            //键盘断开连接
            if ExternalGameControllerUtils.shared.linkedControllers.count == 0 {
                self?.updateSkin()
            }
        }
        ///投屏监听
        sceneWillConnectNotification = NotificationCenter.default.addObserver(forName: UIScene.willConnectNotification, object: nil, queue: .main) { [weak self] notification in
            //投屏开始
            self?.updateAirPlay()
        }
        sceneDidDisconnectNotification = NotificationCenter.default.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: .main) { [weak self] notification in
            //投屏结束
            self?.updateAirPlay()
        }
        
        scenewillDeactivateNotification = NotificationCenter.default.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: .main) { [weak self] notification in
            //进入后台
            guard let self = self else { return }
            if self.manicGame.gameType == ._3ds {
                self.threeDSCore?.pause()
            } else if self.manicGame.gameType.isLibretroType {
                LibretroCore.sharedInstance().pause()
            }
        }
        
        sceneDidActivateNotification = NotificationCenter.default.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { [weak self] notification in
            //从后台回到前台
            self?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            guard let self = self else { return }
            if (self.manicGame.gameType == ._3ds || self.manicGame.gameType.isLibretroType) && self.gameViewControllerShouldResume(self) {
                self.resumeEmulationAndHandleAudio()
            }
        }
        
        //keywindow变化
        windowDidBecomeKeyNotification = NotificationCenter.default.addObserver(forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] notification in
            self?.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        }
        
        //购买会员成功
        membershipNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.MembershipChange, object: nil, queue: .main) { [weak self] notification in
            if PurchaseManager.isMember {
                UIView.hideAllAlert { [weak self] in
                    if ExternalSceneDelegate.isAirPlaying {
                        if Settings.defalut.airPlay {
                            self?.updateAirPlay()
                        } else {
                            //如果在AirPlay 并且还没有设置开启AirPlay 则询问是否开启全屏
                            UIView.makeAlert(detail: R.string.localizable.turnOnAirPlayAsk(), confirmTitle: R.string.localizable.confirmTitle(), confirmAction: { [weak self] in
                                Settings.change { realm in
                                    Settings.defalut.airPlay = true
                                }
                                self?.updateAirPlay()
                            }, hideAction: { [weak self] in
                                self?.resumeEmulationAndHandleAudio()
                            })
                        }
                    } else {
                        self?.resumeEmulationAndHandleAudio()
                    }
                }
            }
        }
        
        //监听控制器映射变化
        controllerMappingNotification = NotificationCenter.default.addObserver(forName: Constants.NotificationName.ControllerMapping, object: nil, queue: .main) { [weak self] notification in
            self?.updateExternalGameController()
        }
        
        //更新最新游戏时间
        updateLatestPlayDate()
        
        //开始计时器
        repeatTimer.resume()
        
        //监听作弊码变化
        cheatCodeUpdateToken = manicGame.gameCheats.observe { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .update(_ , let deletions, let insertions, let modifications):
                if !deletions.isEmpty || !insertions.isEmpty || !modifications.isEmpty {
                    self.updateCheatCodes()
                }
            default:
                break
            }
        }
        
        //监听游戏变化
        gameUpdateToken = manicGame.observe(keyPaths: [\Game.portraitSkin, \Game.landscapeSkin, \Game.filterName, \Game.orientation, \Game.haptic, \Game.volume]) { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .change(_, let properties):
                Log.debug("游戏运行中，游戏更新")
                for property in properties {
                    if property.name == "filterName" {
                        //滤镜更新了
                        self.updateFilter()
                    } else if property.name == "portraitSkin" || property.name == "landscapeSkin" {
                        //暂停所有游戏画面
                        self.gameViews.forEach { gameView in
                            gameView.isEnabled = false
                        }
                        //皮肤更新
                        self.updateSkin()
                    } else if property.name == "orientation" {
                        //更新屏幕方向
                        self.startOrientation()
                    } else if property.name == "haptic" {
                        //修改震感
                        self.updateHaptic()
                    }
                    //如果快捷功能的图标会变化 也需要更新
                    if property.name == "volume" ||  property.name == "haptic" {
                        let settings = Settings.defalut
                        if let controllerSkin = controllerView.controllerSkin,
                            let skin = Database.realm.objects(Skin.self).first(where: { $0.identifier == controllerSkin.identifier }),
                            skin.skinType == .default,
                           settings.displayGamesFunctionCount > 0 {
                            if property.name == "volume", settings.gameFunctionList.prefix(settings.displayGamesFunctionCount).contains(where: { $0 == GameSetting.ItemType.volume.rawValue }) {
                                self.updateFunctionButton()
                            } else if property.name == "haptic", settings.gameFunctionList.prefix(settings.displayGamesFunctionCount).contains(where: { $0 == GameSetting.ItemType.haptic.rawValue }) {
                                self.updateFunctionButton()
                            }
                        }
                    }
                    
                    Log.debug("设置更新 Property '\(property.name)' changed from \(property.oldValue == nil ? "nil" : property.oldValue!) to '\(property.newValue!)'")
                }
            default:
                break
            }
        }
        
        //监听设置变化
        settingsUpdateToken = Settings.defalut.observe(keyPaths: [\Settings.gameFunctionList, \Settings.displayGamesFunctionCount]) { [weak self] change in
            guard let self = self else { return }
            switch change {
            case .change(_, _):
                self.updateFunctionButton()
            default:
                break
            }
        }
    }
    
    @MainActor required init() {
        fatalError("init() has not been implemented")
    }
    
    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        PlayViewController.currentPlayViewController = self
        
        //发送开始游戏通知
        NotificationCenter.default.post(name: Constants.NotificationName.StartPlayGame, object: nil)
        
        //添加功能按钮容器按钮
        functionButtonContainer.isHidden = true
        view.addSubview(functionButtonContainer)
        functionButtonContainer.snp.makeConstraints { make in
            if manicGame.gameType == .n64 && UIDevice.isPad {
                make.top.equalTo(gameView.snp.bottom).offset(-9)
            } else {
                make.top.equalTo(gameView.snp.bottom)
            }
            make.leading.trailing.equalTo(gameView)
            make.height.equalTo(Constants.Size.ItemHeightMid)
        }
        //设置外设控制器
        updateExternalGameController()
        //如果需要加载默认配置
        loadConfig()
        //更新皮肤
        updateSkin()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if manicGame.gameType != ._3ds && !manicGame.gameType.isLibretroType {
            super.viewWillAppear(animated)
        }
        setOrientationConfig()
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        //更新皮肤
        updateSkin()
        //更新声音
        updateAudio()
        if manicGame.gameType != ._3ds {
            //设置速度
            if manicGame.gameType == .psp && manicGame.speed == .one {
                //如果是PSP平台 并且设置的是1倍速，则启动的时候不设置倍速
            } else {
                manicEmuCore?.setRate(speed: manicGame.speed)
            }
        }
        functionButtonContainer.isHidden = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resetOrientationConfig()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        repeatTimer.suspend()
        //清理AirPlay画面
        if let airPlayViewController = ExternalSceneDelegate.airPlayViewController, let airPlayGameView = airPlayViewController.gameView, manicGame.gameType != ._3ds {
            self.manicEmuCore?.remove(airPlayGameView)
            airPlayGameView.removeFromSuperview()
            airPlayViewController.gameView = nil
        }
        
        if let airPlayViewController = ExternalSceneDelegate.airPlayViewController, let airPlayGameView = airPlayViewController.libretroView, manicGame.gameType.isLibretroType {
            airPlayGameView.parentViewController?.removeFromParent()
            airPlayGameView.removeFromSuperview()
            airPlayViewController.libretroView = nil
        }
        
        #if !SIDE_LOAD
        if manicGame.totalPlayDuration > 30 * 60 * 1000 { //玩超过30分钟 尝试弹起评价
            if let scene = ApplicationSceneDelegate.applicationScene {
                if let showDate = UserDefaults.standard.date(forKey: Constants.DefaultKey.ShowRequestReviewDate), showDate.isInToday {
                    
                } else {
                    SKStoreReviewController.requestReview(in: scene)
                    UserDefaults.standard.set(Date(), forKey: Constants.DefaultKey.ShowRequestReviewDate)
                }
            }
        }
        #endif
        
        if manicGame.gameType == ._3ds {
            threeDSCore?.destory()
        }
        
        PlayViewController.currentPlayViewController = nil
        
        //发送结束游戏通知
        NotificationCenter.default.post(name: Constants.NotificationName.StopPlayGame, object: nil)
        
        //取消静音监听
        if manicGame.gameType.isLibretroType || manicGame.gameType == ._3ds {
            muteSwitchMonitor.stopMonitoring()
        }
    }
    
    /// 进入默认显示的方向
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        if manicGame.orientation == .landscape {
            return .landscapeRight
        } else if manicGame.orientation == .portrait {
            return .portrait
        }
        return super.preferredInterfaceOrientationForPresentation
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        let fromSize = Constants.Size.WindowSize
        let toSize = size
        if manicGame.orientation == .portrait {
            //当前设置为竖屏，只允许从横屏旋转到竖屏
            if fromSize.height > fromSize.width && toSize.height < toSize.width {
                return
            }
        } else if manicGame.orientation == .landscape {
            //当前设置为横屏，允许横屏旋转 或者竖屏到横屏
            if fromSize.height < fromSize.width && toSize.height > toSize.width {
                return
            }
        }
        UIView.hideAllAlert()
        super.viewWillTransition(to: size, with: coordinator)
        guard UIApplication.shared.applicationState != .background else { return }
                
        coordinator.animate(alongsideTransition: { [weak self] (context) in
            guard let self = self else { return }
            self.updateSkin()
            self.view.setNeedsLayout()
        }) { [weak self] _ in
            guard let self = self else { return }
            self.resumeEmulationAndHandleAudio()
        }
    }
    
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge {
        return .all
    }
    
    override func gameController(_ gameController: any GameController, didActivate input: any Input, value: Double) {
        super.gameController(gameController, didActivate: input, value: value)
        //点击menu弹出菜单
        if input.stringValue == "menu" {
            if GameSettingView.isShow {
                UIView.hideAllAlert { [weak self] in
                    self?.resumeEmulationAndHandleAudio()
                }
            } else {
                if manicGame.gameType == ._3ds {
                    threeDSCore?.pause()
                } else if manicGame.gameType.isLibretroType {
                    LibretroCore.sharedInstance().pause()
                } else {
                    pauseEmulation()
                }
                if manicGame.fileExtension.lowercased() == "m3u" {
                    manicGame.totalDiskCount = LibretroCore.sharedInstance().getDiskCount()
                    manicGame.currentDiskIndex = LibretroCore.sharedInstance().getCurrentDiskIndex()
                }
                GameSettingView.show(game: manicGame,
                                     gameViewRect: gameView.frame,
                                     didSelectItem: { [weak self] item, sheet in
                    //点击菜单选项
                    guard let self = self else { return true }
                    return self.handleMenuGameSetting(item, sheet)
                }, hideCompletion: { [weak self] in
                    //隐藏菜单回调
                    guard let self = self else { return }
                    self.resumeEmulationAndHandleAudio()
                })
            }
        } else if input.stringValue == "flex" {
            //缩放游戏画面
            guard gameViews.count > 0 else {
                UIView.makeToast(message: R.string.localizable.flexSkinSettingError())
                return
            }
            
            if manicGame.gameType == ._3ds {
                threeDSCore?.pause()
            } else if manicGame.gameType.isLibretroType {
                LibretroCore.sharedInstance().pause()
            } else {
                pauseEmulation()
            }
            
            func updateFlex(images: [UIImage?]) {
                if let controllerSkin = controllerView.controllerSkin, let traits = controllerView.controllerSkinTraits,
                    let skin = Database.realm.objects(Skin.self).first(where: { $0.identifier == controllerSkin.identifier }) {
                    fixedOrientationConfig()
                    let vc = FlexSkinSettingViewController(skin: skin, traits: traits, images: images)
                    vc.didCompletion = { [weak self] in
                        guard let self = self else { return }
                        self.resumeEmulationAndHandleAudio()
                        self.setOrientationConfig()
                        self.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
                        //更新皮肤
                        self.updateSkin()
                        //更新声音
                        self.updateAudio()
                        if manicGame.gameType != ._3ds {
                            //设置速度
                            self.manicEmuCore?.setRate(speed: manicGame.speed)
                        }
                    }
                    topViewController()?.present(vc, animated: true)
                }
            }
            
            var images = [UIImage?]()
            if manicGame.gameType == ._3ds, let snapShots = snapShotFor3DS() {
                images = snapShots
                updateFlex(images: images)
            } else if manicGame.gameType.isLibretroType {
                LibretroCore.sharedInstance().snapshot { image in
                    updateFlex(images: [image])
                }
            } else {
                let mainGameView = gameViews.first!
                let secondGameView: GameView? = gameViews.count > 1 ? gameViews[1] : nil
                images.append(mainGameView.snapshot())
                if let secondGameView {
                    images.append(secondGameView.snapshot())
                }
                updateFlex(images: images)
            }
        } else if input.stringValue == "quickSave" {
            handleMenuGameSetting(GameSetting(type: .saveState), nil)
        } else if input.stringValue == "quickLoad" {
            handleMenuGameSetting(GameSetting(type: .quickLoadState), nil)
        } else if input.stringValue == "fastForward" {
            if PurchaseManager.isMember {
                manicEmuCore?.setRate(speed: .two)
            } else {
                if manicGame.speed.rawValue < GameSetting.FastForwardSpeed.five.rawValue {
                    manicEmuCore?.setRate(speed: .five)
                }
            }
        } else if input.stringValue == "toggleFastForward" {
            handleMenuGameSetting(GameSetting(type: .fastForward, fastForwardSpeed: manicGame.speed.next), nil)
        } else if input.stringValue == "reverseScreens" {
            handleMenuGameSetting(GameSetting(type: .swapScreen), nil)
        } else if input.stringValue == "volume" {
            handleMenuGameSetting(GameSetting(type: .volume, volumeOn: !manicGame.volume), nil)
        } else if input.stringValue == "saveStates" {
            handleMenuGameSetting(GameSetting(type: .stateList), nil)
        } else if input.stringValue == "cheatCodes" {
            handleMenuGameSetting(GameSetting(type: .cheatCode), nil)
        } else if input.stringValue == "skins" {
            handleMenuGameSetting(GameSetting(type: .skins), nil)
        } else if input.stringValue == "filters" {
            handleMenuGameSetting(GameSetting(type: .filter), nil)
        } else if input.stringValue == "screenshot" {
            handleMenuGameSetting(GameSetting(type: .screenShot), nil)
        } else if input.stringValue == "haptics" {
            handleMenuGameSetting(GameSetting(type: .haptic, hapticType: manicGame.haptic.next), nil)
        } else if input.stringValue == "controllers" {
            handleMenuGameSetting(GameSetting(type: .controllerSetting), nil)
        } else if input.stringValue == "orientation" {
            handleMenuGameSetting(GameSetting(type: .orientation, orientation: manicGame.orientation.next), nil)
        } else if input.stringValue == "functionLayout" {
            handleMenuGameSetting(GameSetting(type: .functionSort), nil)
        } else if input.stringValue == "restart" {
            handleMenuGameSetting(GameSetting(type: .reload), nil)
        } else if input.stringValue == "resolution" {
            handleMenuGameSetting(GameSetting(type: .resolution, resolution: manicGame.resolution.next), nil)
        } else if input.stringValue == "quit" {
            handleMenuGameSetting(GameSetting(type: .quit), nil)
        } else if input.stringValue == "amiibo" {
            handleMenuGameSetting(GameSetting(type: .amiibo), nil)
        } else if input.stringValue == "homeMenu" {
            handleMenuGameSetting(GameSetting(type: .consoleHome), nil)
        } else if input.stringValue == "airplay" {
            handleMenuGameSetting(GameSetting(type: .airplay), nil)
        } else if input.stringValue == "toggleControlls" {
            handleMenuGameSetting(GameSetting(type: .toggleFullscreen, isFullScreen: !manicGame.forceFullSkin), nil)
        } else if input.stringValue == "blowing" {
            handleMenuGameSetting(GameSetting(type: .simBlowing), nil)
        } else if input.stringValue == "palette" {
            handleMenuGameSetting(GameSetting(type: .palette, palette: manicGame.pallete.next), nil)
        } else if input.stringValue == "swapDisk" {
            let currentIndex = LibretroCore.sharedInstance().getCurrentDiskIndex()
            let totalCount = LibretroCore.sharedInstance().getDiskCount()
            let nextIndex = currentIndex + 1 < totalCount ? currentIndex + 1 : 0
            handleMenuGameSetting(GameSetting(type: .swapDisk, currentDiskIndex: nextIndex), nil)
        }
    }
    
    override func gameController(_ gameController: any GameController, didDeactivate input: any Input) {
        super.gameController(gameController, didDeactivate: input)
        if input.stringValue == "fastForward" {
            manicEmuCore?.setRate(speed: manicGame.speed)
        }
    }
}

//MARK: 私有方法
extension PlayViewController {
    /// 计算游戏时间
    private func calculatePlayTime() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let latestPlayDate =  manicGame.latestPlayDate {
                Game.change { realm in
                    self.manicGame.latestPlayDuration = Date().timeIntervalSince1970ms - latestPlayDate.timeIntervalSince1970ms
                    self.manicGame.totalPlayDuration += Double(Constants.Numbers.AutoSaveGameDuration*1000)
                }
                Log.debug("记录游戏时间")
            }
        }
    }
    
    private func saveStateFor3DS(type: GameSaveStateType) {
        let now = Date.now
        if type == .manualSaveState, let lastSaveDate = lastSaveDate, now.timeIntervalSince1970ms - lastSaveDate.timeIntervalSince1970ms < 5000 {
            UIView.makeToast(message: R.string.localizable.saveStateTooFrequent(), identifier: "saveStateTooFrequent")
            return
        }
            
        if let threeDSCore = self.threeDSCore {
            let now = Date()
            //存档 并获取存档路径
            let result = threeDSCore.saveState()
            if result.isSuccess {
                var image: UIImage? = nil
                if let tempImage = snapShotFor3DS(topOnly: true)?.first {
                    image = tempImage.scaled(toHeight: 150)
                }
                DispatchQueue.main.asyncAfter(delay: 2) {
                    let state = GameSaveState()
                    state.name = "\(now.string(withFormat: Constants.Strings.FileNameTimeFormat))_" + result.path.lastPathComponent
                    state.type = type
                    state.date = now
                    if let imageData = image?.jpegData(compressionQuality: 0.7) {
                        state.stateCover = CreamAsset.create(objectID: state.name, propName: "stateCover", data: imageData)
                    }
                    state.stateData = CreamAsset.create(objectID: state.name, propName: "stateData", url: URL(fileURLWithPath: result.path))
                    let autoSaveStates = self.manicGame.gameSaveStates.where({ $0.type == .autoSaveState }).sorted(by: \GameSaveState.date)
                    Game.change { realm in
                        //自动保存的数量最多只能保存AutoSaveGameCount个
                        if autoSaveStates.count >= Constants.Numbers.AutoSaveGameCount {
                            let needToDeletes = autoSaveStates.prefix(autoSaveStates.count - Constants.Numbers.AutoSaveGameCount + 1)
                            CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateCover }), realm: realm)
                            CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateData }), realm: realm)
                            if Settings.defalut.iCloudSyncEnable {
                                needToDeletes.forEach { $0.isDeleted = true }
                            } else {
                                realm.delete(needToDeletes)
                            }
                        }
                        self.manicGame.gameSaveStates.append(state)
                    }
                    if type == .manualSaveState {
                        self.lastSaveDate = Date.now
                        UIView.makeToast(message: R.string.localizable.gameSaveStateSuccess(), identifier: "gameSaveStateSuccess")
                    }
                    Log.debug("保存即时存档")
                }
            }
        }
    }
    
    private func saveStateForLibretro(type: GameSaveStateType) {
        let now = Date.now
        if type == .manualSaveState, let lastSaveDate = lastSaveDate, now.timeIntervalSince1970ms - lastSaveDate.timeIntervalSince1970ms < 3000 {
            UIView.makeToast(message: R.string.localizable.saveStateTooFrequent(), identifier: "saveStateTooFrequent")
            return
        }
        LibretroCore.sharedInstance().snapshot { image in
            let submitSuccess = LibretroCore.sharedInstance().saveState { statePath in
                if let statePath {
                    let now = Date.now
                    let state = GameSaveState()
                    state.name = "\(now.string(withFormat: Constants.Strings.FileNameTimeFormat))_" + self.manicGame.fileName
                    state.type = type
                    state.date = now
                    if let imageData = image?.scaled(toHeight: 150)?.jpegData(compressionQuality: 0.7) {
                        state.stateCover = CreamAsset.create(objectID: state.name, propName: "stateCover", data: imageData)
                    }
                    state.stateData = CreamAsset.create(objectID: state.name, propName: "stateData", url: URL(fileURLWithPath: statePath))
                    let autoSaveStates = self.manicGame.gameSaveStates.where({ $0.type == .autoSaveState }).sorted(by: \GameSaveState.date)
                    Game.change { realm in
                        //自动保存的数量最多只能保存AutoSaveGameCount个
                        if autoSaveStates.count >= Constants.Numbers.AutoSaveGameCount {
                            let needToDeletes = autoSaveStates.prefix(autoSaveStates.count - Constants.Numbers.AutoSaveGameCount + 1)
                            CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateCover }), realm: realm)
                            CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateData }), realm: realm)
                            if Settings.defalut.iCloudSyncEnable {
                                needToDeletes.forEach { $0.isDeleted = true }
                            } else {
                                realm.delete(needToDeletes)
                            }
                        }
                        self.manicGame.gameSaveStates.append(state)
                    }
                    if type == .manualSaveState {
                        self.lastSaveDate = Date.now
                    }
                    Log.debug("保存即时存档")
                }
            }
            if submitSuccess && type != .autoSaveState {
                UIView.makeToast(message: R.string.localizable.gameSaveStateSuccess(), identifier: "gameSaveStateSuccess")
            }
        }
    }
    
    /// 存储即时存档
    /// - Parameter type: 存档类型
    private func saveState(type: GameSaveStateType) {
        if manicGame.gameType == ._3ds || manicGame.gameType.isLibretroType {
            return
        }
        let now = Date.now
        if type == .manualSaveState, let lastSaveDate = lastSaveDate, now.timeIntervalSince1970ms - lastSaveDate.timeIntervalSince1970ms < 1000 {
            UIView.makeToast(message: R.string.localizable.saveStateTooFrequent(), identifier: "saveStateTooFrequent")
            return
        }
            
        if let manicEmuCore = self.manicEmuCore {
            //游戏暂停时不能自动存储即时存档
            guard manicEmuCore.state == .running || type == .manualSaveState else { return }
            let now = Date()
            if !FileManager.default.fileExists(atPath: Constants.Path.SaveStateWorkSpace) {
                try? FileManager.default.createDirectory(atPath: Constants.Path.SaveStateWorkSpace, withIntermediateDirectories: true)
            }
            let fileUrl = URL(fileURLWithPath: Constants.Path.SaveStateWorkSpace).appendingPathComponent("\(now.timeIntervalSince1970).savestate")
            pauseEmulation()
            manicEmuCore.saveSaveState(to: fileUrl)
            resumeEmulationAndHandleAudio()
            if FileManager.default.fileExists(atPath: fileUrl.path) {
                var image = manicEmuCore.videoManager.snapshot()
                if manicGame.gameType == .ds, let tempImage = image {
                    image = tempImage.cropped(to: CGRect(origin: .zero, size: CGSize(width: tempImage.size.width, height: tempImage.size.height/2))).scaled(toHeight: 150)
                }
                let state = GameSaveState()
                state.name = "\(manicGame.id)_\(now.string(withFormat: Constants.Strings.FileNameTimeFormat))"
                state.type = type
                state.date = now
                if let imageData = image?.jpegData(compressionQuality: 0.7) {
                    state.stateCover = CreamAsset.create(objectID: state.name, propName: "stateCover", data: imageData)
                }
                state.stateData = CreamAsset.create(objectID: state.name, propName: "stateData", url: fileUrl)
                let autoSaveStates = self.manicGame.gameSaveStates.where({ $0.type == .autoSaveState }).sorted(by: \GameSaveState.date)
                Game.change { realm in
                    //自动保存的数量最多只能保存AutoSaveGameCount个
                    if autoSaveStates.count >= Constants.Numbers.AutoSaveGameCount {
                        let needToDeletes = autoSaveStates.prefix(autoSaveStates.count - Constants.Numbers.AutoSaveGameCount + 1)
                        CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateCover }), realm: realm)
                        CreamAsset.batchDeleteAndClean(assets: needToDeletes.compactMap({ $0.stateData }), realm: realm)
                        if Settings.defalut.iCloudSyncEnable {
                            needToDeletes.forEach { $0.isDeleted = true }
                        } else {
                            realm.delete(needToDeletes)
                        }
                    }
                    self.manicGame.gameSaveStates.append(state)
                }
                if type == .manualSaveState {
                    self.lastSaveDate = Date.now
                    UIView.makeToast(message: R.string.localizable.gameSaveStateSuccess(), identifier: "gameSaveStateSuccess")
                }
                Log.debug("保存即时存档")
            }
        }
    }
    
    private func quickLoadStateFor3DS(_ state: GameSaveState?) {
        let now = Date.now
        if let lastLoadDate = lastLoadDate, now.timeIntervalSince1970ms - lastLoadDate.timeIntervalSince1970ms < 5000 {
            UIView.makeToast(message: R.string.localizable.loadStateTooFrequent(), identifier: "loadStateTooFrequent")
            return
        }
        //如果传入即时存档就尝试去加载 如果没有传入则选最新的手动即时存档进行读取
        if let state = state ?? manicGame.gameSaveStates.last(where: { $0.type == .manualSaveState }),
            let threeDSCore = self.threeDSCore,
            let slot = UInt32(state.name.deletingPathExtension.pathExtension) {
            //现将存档移到模拟器工作目录
            if let fileUrl = state.stateData?.filePath {
                threeDSCore.addSaveState(fileUrl: fileUrl, slot: slot)
            }
            threeDSCore.loadState(slot)
            UIView.makeToast(message: R.string.localizable.gameSaveStateLoadSuccess())
            lastLoadDate = Date.now
            updateCheatCodes()
        } else {
            UIView.makeToast(message: R.string.localizable.gameSaveStateQuickLoadFailed())
        }
    }
    
    private func quickLoadStateForLibretro(_ state: GameSaveState?) {
        let now = Date.now
        if let lastLoadDate = lastLoadDate, now.timeIntervalSince1970ms - lastLoadDate.timeIntervalSince1970ms < 1000 {
            UIView.makeToast(message: R.string.localizable.loadStateTooFrequent(), identifier: "loadStateTooFrequent")
            return
        }
        //如果传入即时存档就尝试去加载 如果没有传入则选最新的手动即时存档进行读取
        if let state = state ?? manicGame.gameSaveStates.last(where: { $0.type == .manualSaveState }), let statePath = state.stateData?.filePath.path, LibretroCore.sharedInstance().loadState(statePath) {
            resumeEmulationAndHandleAudio()
            UIView.makeToast(message: R.string.localizable.gameSaveStateLoadSuccess())
            lastLoadDate = Date.now
            updateCheatCodes()
        } else {
            UIView.makeToast(message: R.string.localizable.gameSaveStateQuickLoadFailed())
        }
    }
    
    /// 快速加载即时存档
    /// - Parameter state: 即时存档
    private func quickLoadStateAndResume(_ state: GameSaveState?) {
        let now = Date.now
        if let lastLoadDate = lastLoadDate, now.timeIntervalSince1970ms - lastLoadDate.timeIntervalSince1970ms < 1000 {
            UIView.makeToast(message: R.string.localizable.loadStateTooFrequent(), identifier: "loadStateTooFrequent")
            return
        }
        //如果传入即时存档就尝试去加载 如果没有传入则选最新的手动即时存档进行读取
        if let state = state ?? manicGame.gameSaveStates.last(where: { $0.type == .manualSaveState }), let fileUrl = state.stateData?.filePath, let manicEmuCore = self.manicEmuCore {
            manicEmuCore.stop()
            manicEmuCore.videoManager.isEnabled = false
            manicEmuCore.start()
            manicEmuCore.pause()
            do {
                try manicEmuCore.load(SaveState(fileURL: fileUrl, gameType: manicGame.gameType), ignoreActivatedInputs: true)
                UIView.makeToast(message: R.string.localizable.gameSaveStateLoadSuccess())
                lastLoadDate = Date.now
            } catch {
                Log.debug("加载存档失败:\(error)")
                UIView.makeToast(message: R.string.localizable.gameSaveStateLoadFailed())
            }
            manicEmuCore.videoManager.isEnabled = true
            resumeEmulationAndHandleAudio()
            updateCheatCodes()
        } else {
            UIView.makeToast(message: R.string.localizable.gameSaveStateQuickLoadFailed())
        }
    }
    
    /// 处理菜单点击
    /// - Parameter item: 菜单选项
    /// - Returns: 是否关闭菜单
    @discardableResult
    private func handleMenuGameSetting(_ item: GameSetting, _ menuSheet: SheetTarget?) -> Bool {
        guard item.enable(for: manicGame.gameType) else {
            UIView.makeToast(message: R.string.localizable.notSupportGameSetting(manicGame.gameType.localizedShortName))
            return false
        }
        switch item.type {
        case .saveState:
            //快速存档
            if !PurchaseManager.isMember && manicGame.gameSaveStates.filter({ $0.type == .manualSaveState }).count >= Constants.Numbers.NonMemberManualSaveGameCount {
                //超限了
                if menuSheet == nil {
                    if manicGame.gameType == ._3ds {
                        threeDSCore?.pause()
                    } else if manicGame.gameType.isLibretroType {
                        LibretroCore.sharedInstance().pause()
                    } else {
                        pauseEmulation()
                    }
                }
                UIView.makeAlert(identifier: Constants.Strings.PlayPurchaseAlertIdentifier,
                                 detail: R.string.localizable.manualGameSaveCountLimit(),
                                 confirmTitle: R.string.localizable.goToUpgrade(),
                                 confirmAutoHide: false,
                                 confirmAction: {
                    topViewController()?.present(PurchaseViewController(), animated: true)
                }) { [weak self] in
                    if menuSheet == nil {
                        self?.resumeEmulationAndHandleAudio()
                    }
                }
                return false
            }
            
            //没有超限 则继续存储
            if manicGame.gameType == ._3ds {
                saveStateFor3DS(type: .manualSaveState)
            } else if manicGame.gameType.isLibretroType {
                saveStateForLibretro(type: .manualSaveState)
            } else {
                saveState(type: .manualSaveState)
            }
        case .quickLoadState:
            //快速读档
            if manicGame.gameType == ._3ds {
                quickLoadStateFor3DS(item.loadState)
            } else if manicGame.gameType.isLibretroType {
                quickLoadStateForLibretro(item.loadState)
            } else {
                quickLoadStateAndResume(item.loadState)
            }
        case .volume:
            //声音设置
            //恢复游戏的时候会直接使用新配置
            Game.change { realm in
                manicGame.volume = item.volumeOn
            }
            prefersVolumeEnable = item.volumeOn
            if menuSheet == nil {
                //说明这里不是由menu菜单进行设置的 则不存在恢复游戏的过程 所以需要手动更新声音
                updateAudio()
            }
            UIView.makeToast(message: item.volumeOn ? R.string.localizable.volumeOn(): R.string.localizable.volumeOff(), identifier: "gameVolume")
        case .fastForward:
            guard manicGame.gameType != ._3ds else { return true }
            //快进
            if !PurchaseManager.isMember && item.fastForwardSpeed.rawValue > GameSetting.FastForwardSpeed.two.rawValue {
                //超限了
                if menuSheet == nil {
                    if manicGame.gameType.isLibretroType {
                        LibretroCore.sharedInstance().pause()
                    } else {
                        pauseEmulation()
                    }
                }
                UIView.makeAlert(identifier: Constants.Strings.PlayPurchaseAlertIdentifier,
                                 detail: R.string.localizable.fastForwardSpeedLimit(),
                                 cancelTitle: R.string.localizable.resetSpeed(),
                                 confirmTitle: R.string.localizable.goToUpgrade(),
                                 confirmAutoHide: false, cancelAction: { [weak self] in
                    guard let self = self else { return }
                    self.manicEmuCore?.setRate(speed: .one)
                    Game.change { realm in
                        self.manicGame.speed = .one
                    }
                    UIView.makeToast(message: R.string.localizable.gameSettingFastForwardResume())
                }, confirmAction: {
                    topViewController()?.present(PurchaseViewController(), animated: true)
                }) { [weak self] in
                    if menuSheet == nil {
                        self?.resumeEmulationAndHandleAudio()
                    }
                }
            } else {
                
                if manicGame.speed.rawValue == 0 || manicGame.speed != item.fastForwardSpeed {
                    manicEmuCore?.setRate(speed: item.fastForwardSpeed)
                    Game.change { realm in
                        manicGame.speed = item.fastForwardSpeed
                    }
                }
                UIView.makeToast(message: item.fastForwardSpeed == .one ? R.string.localizable.gameSettingFastForwardResume() : item.fastForwardSpeed.title, identifier: "gameSpeed")
            }
            return false
        case .stateList:
            if menuSheet == nil {
                if manicGame.gameType == ._3ds {
                    threeDSCore?.pause()
                } else if manicGame.gameType.isLibretroType {
                    LibretroCore.sharedInstance().pause()
                } else {
                    self.pauseEmulation()
                }
            }
            GameInfoView.show(game: manicGame, gameViewRect: gameView.frame, selection: { [weak self, weak menuSheet] saveState in
                guard let self = self else { return }
                func loadSave() {
                    if self.manicGame.gameType == ._3ds {
                        DispatchQueue.main.asyncAfter(delay: 1) {
                            self.resumeEmulationAndHandleAudio()
                            self.quickLoadStateFor3DS(saveState)
                        }
                    } else if self.manicGame.gameType.isLibretroType {
                        self.quickLoadStateForLibretro(saveState)
                    } else {
                        self.quickLoadStateAndResume(saveState)
                    }
                }
                if menuSheet == nil {
                    loadSave()
                } else {
                    if self.manicGame.gameType.isLibretroType {
                        loadSave()
                        menuSheet?.pop()
                    } else {
                        menuSheet?.pop {
                            loadSave()
                        }
                    }
                }
            }, hideCompletion: { [weak self] in
                if menuSheet == nil {
                    self?.resumeEmulationAndHandleAudio()
                }
            })
            return false
        case .cheatCode:
            if manicGame.gameType == .ss && manicGame.defaultCore == 0 {
                UIView.makeToast(message: R.string.localizable.beetleSaturnNoSupportCheat())
            } else {
                if menuSheet == nil {
                    if manicGame.gameType.isLibretroType {
                        LibretroCore.sharedInstance().pause()
                    } else {
                        pauseEmulation()
                    }
                }
                CheatCodeListView.show(game: manicGame, gameViewRect: gameView.frame, hideCompletion: { [weak self] in
                    if menuSheet == nil {
                        self?.resumeEmulationAndHandleAudio()
                    }
                })
            }
            return false
        case .skins:
            if menuSheet == nil {
                if manicGame.gameType == ._3ds {
                    threeDSCore?.pause()
                } else if manicGame.gameType.isLibretroType {
                    LibretroCore.sharedInstance().pause()
                } else {
                    pauseEmulation()
                }
            }
            SkinSettingsView.show(game: manicGame, gameViewRect: gameView.frame, hideCompletion: { [weak self] in
                if menuSheet == nil {
                    self?.resumeEmulationAndHandleAudio()
                }
            })
            return false
        case .filter:
            guard manicGame.gameType != ._3ds else { return true }
            if menuSheet == nil {
                if manicGame.gameType.isLibretroType {
                    LibretroCore.sharedInstance().pause()
                } else {
                    pauseEmulation()
                }
            }
            if manicGame.gameType.isLibretroType {
                FilterSelectionView.show(game: self.manicGame, snapshot: nil, gameViewRect: self.gameView.frame, hideCompletion: { [weak self] in
                    if menuSheet == nil {
                        self?.resumeEmulationAndHandleAudio()
                    }
                })
            } else {
                var snapshot = manicEmuCore?.videoManager.snapshot()
                if manicGame.gameType == .ds, let temp = snapshot {
                    snapshot = temp.cropped(to: CGRect(origin: .zero, size: CGSize(width: temp.size.width, height: temp.size.height/2)))
                }
                FilterSelectionView.show(game: manicGame, snapshot: snapshot, gameViewRect: gameView.frame, hideCompletion: { [weak self] in
                    if menuSheet == nil {
                        self?.resumeEmulationAndHandleAudio()
                    }
                })
            }
            return false
        case .screenShot:
            //截屏
            if manicGame.gameType == ._3ds {
                if let images = self.snapShotFor3DS() {
                    DispatchQueue.global().asyncAfter(delay: menuSheet == nil ? 0 : 1, execute: {
                        var imageDatas = [Data]()
                        for image in images {
                            if let imageData = image.jpegData(compressionQuality: 0.7) {
                                imageDatas.append(imageData)
                            }
                        }
                        if imageDatas.count > 0 {
                            PhotoSaver.save(datas: imageDatas)
                        }
                    })
                }
            } else if manicGame.gameType.isLibretroType {
                DispatchQueue.main.asyncAfter(delay: menuSheet == nil ? 0 : 1, execute: {
                    LibretroCore.sharedInstance().snapshot { image in
                        if let image {
                            PhotoSaver.save(image: image);
                        }
                    }
                })
            } else {
                PhotoSaver.save(datas: gameViews.compactMap { $0.snapshot()?.processGameSnapshop() })
                return false
            }
        case .haptic:
            switch item.hapticType {
            case .off:
                break
            case .soft:
                Haptic.impact(.soft).generate()
            case .light:
                Haptic.impact(.light).generate()
            case .medium:
                Haptic.impact(.medium).generate()
            case .heavy:
                Haptic.impact(.heavy).generate()
            case .rigid:
                Haptic.impact(.rigid).generate()
            }
            if manicGame.haptic != item.hapticType {
                Game.change { realm in
                    manicGame.haptic = item.hapticType
                }
            }
            UIView.makeToast(message: item.hapticType.title, identifier: "hapticType")
            return false
        case .airplay:
            if menuSheet == nil {
                if manicGame.gameType == ._3ds {
                    threeDSCore?.pause()
                } else if manicGame.gameType.isLibretroType {
                    LibretroCore.sharedInstance().pause()
                } else {
                    pauseEmulation()
                }
            }
            let vc = WebViewController(url: Constants.URLs.AirPlayUsageGuide, isShow: true)
            vc.didClose = { [weak self] in
                if menuSheet == nil {
                    self?.resumeEmulationAndHandleAudio()
                }
            }
            topViewController()?.present(vc, animated: true)
            return false
        case .controllerSetting:
            if menuSheet == nil {
                if manicGame.gameType == ._3ds {
                    threeDSCore?.pause()
                } else if manicGame.gameType.isLibretroType {
                    LibretroCore.sharedInstance().pause()
                } else {
                    pauseEmulation()
                }
            }
            ControllersSettingView.show(gameType: manicGame.gameType, gameViewRect: gameView.frame, hideCompletion: { [weak self] in
                if menuSheet == nil {
                    self?.resumeEmulationAndHandleAudio()
                }
            })
            return false
        case .orientation:
            if manicGame.orientation != item.orientation {
                Game.change { realm in
                    manicGame.orientation = item.orientation
                }
                //旋转需要时间 旋转结束再弹出toast
                DispatchQueue.main.asyncAfter(delay: 0.5) {
                    UIView.makeToast(message: item.orientation.title)
                }
            } else {
                UIView.makeToast(message: item.orientation.title)
            }
            return true
        case .functionSort:
            if menuSheet == nil {
                if manicGame.gameType == ._3ds {
                    threeDSCore?.pause()
                } else if manicGame.gameType.isLibretroType {
                    LibretroCore.sharedInstance().pause()
                } else {
                    pauseEmulation()
                }
            }
            GameSettingView.show(game: manicGame, gameViewRect: gameView.frame, isEditingMode: true, hideCompletion: { [weak self] in
                if menuSheet == nil {
                    self?.resumeEmulationAndHandleAudio()
                }
            })
            return false
        case .reload:
            if manicGame.gameType == ._3ds {
                threeDSCore?.reload()
            } else if manicGame.gameType.isLibretroType {
                LibretroCore.sharedInstance().reload()
                updateFilter()
            } else {
                manicEmuCore?.stop()
                manicEmuCore?.start()
            }
        case .quit:
            if manicGame.gameType == ._3ds {
                threeDSCore?.stop()
                DispatchQueue.main.asyncAfter(delay: 0.5) {
                    self.dismiss(animated: true)
                }
            } else if manicGame.gameType.isLibretroType {
                LibretroCore.sharedInstance().stop()
                gameMetalView = nil;
                DispatchQueue.main.asyncAfter(delay: 0.5) {
                    self.dismiss(animated: true)
                }
            } else {
                manicEmuCore?.stop()
                dismiss(animated: true)
            }
        case .resolution:
            guard manicGame.gameType == ._3ds || manicGame.gameType == .psp || manicGame.gameType == .n64 else { return true }
            Log.debug("设置分辨率")
            if manicGame.resolution != item.resolution {
                Game.change { realm in
                    manicGame.resolution = item.resolution
                }
                if manicGame.gameType == ._3ds {
                    threeDSCore?.setResolution(resolution: item.resolution)
                } else if manicGame.gameType == .psp {
                    LibretroCore.sharedInstance().setPSPResolution(UInt32(item.resolution == .undefine ? 1 : item.resolution.rawValue), reload: true)
                } else if manicGame.gameType == .n64 {
                    updateN64Resolution(item.resolution, reload: true)
                }
            }
            UIView.makeToast(message: item.resolution.title, identifier: "resolution")
            return manicGame.gameType == .psp //psp需要隐藏菜单(恢复游戏) 才能生效
        case .swapScreen:
            if enableSwapScreen() {
                Game.change { realm in
                    manicGame.swapScreen = !manicGame.swapScreen
                }
                updateSkin()
            }
            if manicGame.gameType == .ds {
                updateAirPlay()
            }
        case .consoleHome:
            //回到主页
            if manicGame.gameType == ._3ds, let threeDSCore {
                if Constants.Strings.ThreeDSHomeMenuIdentifier == "\(manicGame.identifierFor3DS)" ||
                    Constants.Strings.ThreeDSHomeMenuIdentifier2 == "\(manicGame.identifierFor3DS)" {
                    DispatchQueue.main.asyncAfter(delay: 0.5) {
                        threeDSCore.jumpToHome()
                    }
                } else {
                    UIView.makeToast(message: R.string.localizable.threeDSHomeMenuNotRunning())
                }
            }
        case .amiibo:
            //加载amiibo
            if manicGame.gameType == ._3ds, let threeDSCore {
                if threeDSCore.isAmiiboSearching() {
                    if menuSheet == nil {
                        threeDSCore.pause()
                    }
                    Log.debug("amiibo正在搜索中")
                    FilesImporter.shared.presentImportController(supportedTypes: UTType.binTypes, allowsMultipleSelection: false) { [weak self] urls in
                        guard let self = self else { return }
                        self.resumeEmulationAndHandleAudio()
                        UIView.hideAllAlert { [weak self] in
                            guard let self = self else { return }
                            if let url = urls.first {
                                DispatchQueue.main.asyncAfter(delay: 1) {
                                    self.threeDSCore?.loadAmiibo(path: url.path)
                                }
                            }
                        }
                    }
                    return false
                } else {
                    Log.debug("amiibo没有搜索")
                    UIView.makeToast(message: R.string.localizable.amiiboNotSearching())
                }
            }
        case .toggleFullscreen:
            manicGame.forceFullSkin = item.isFullScreen
            updateSkin()
            
        case .simBlowing:
            guard manicGame.gameType == ._3ds else { return false }
            threeDSCore?.setSimBlowing(start: true)
            DispatchQueue.main.asyncAfter(delay: 5) { [weak self] in
                self?.threeDSCore?.setSimBlowing(start: false)
            }
            
        case .palette:
            guard (manicGame.gameType == .gbc || manicGame.gameType == .gb) else { return false }
            if manicGame.pallete != item.palette {
                Game.change { realm in
                    manicGame.pallete = item.palette
                }
                manicEmuCore?.manicCore.emulatorConnector.setExtraParameters?(["palette": item.palette.rawValue])
            }
        case .swapDisk:
            guard manicGame.gameType == .mcd || manicGame.gameType == .ss else { return false }
            if manicGame.fileExtension.lowercased() == "m3u" {
                LibretroCore.sharedInstance().setDiskIndex(UInt32(item.currentDiskIndex))
            } else {
                UIView.makeToast(message: R.string.localizable.notSupportSwapDisk())
            }
            return false
        }
        //默认关闭菜单
        return true
    }
    
    //更新外设控制器
    private func updateExternalGameController() {
        if let manicEmuCore = self.manicEmuCore {
            let realm = Database.realm
            for controler in ExternalGameControllerUtils.shared.linkedControllers {
                var mapping: GameControllerInputMapping? = nil
                if let object = realm.objects(ControllerMapping.self).first(where: { $0.controllerName == controler.name && $0.gameType == manicGame.gameType && !$0.isDeleted }) {
                    mapping = try? GameControllerInputMapping(mapping: object.mapping)
                }
                if let mapping {
                    controler.addReceiver(self, inputMapping: mapping)
                    controler.addReceiver(manicEmuCore, inputMapping: mapping)
                } else {
                    controler.addReceiver(self)
                    controler.addReceiver(manicEmuCore)
                }
            }
        }
    }
    
    /// 更新最近游戏时间
    private func updateLatestPlayDate() {
        let date = Date()
        Log.debug("开始游戏: \(date.timeIntervalSince1970ms)")
        Game.change { _ in
            self.manicGame.latestPlayDate = date
        }
    }
    
    private func resumeEmulationAndHandleAudio() {
        if manicGame.gameType == ._3ds {
            threeDSCore?.resume()
            updateAudio()
        } else if manicGame.gameType.isLibretroType {
            LibretroCore.sharedInstance().resume()
            updateAudio()
        } else {
            resumeEmulation()
            updateAudio()
            if PurchaseManager.isMember, Settings.defalut.airPlay, ExternalSceneDelegate.isAirPlaying, let airPlayGameView = ExternalSceneDelegate.airPlayViewController?.gameView {
                if !airPlayGameView.isEnabled {
                    airPlayGameView.isEnabled = true
                }
            } else {
                gameViews.forEach { gameView in
                    if !gameView.isEnabled {
                        gameView.isEnabled = true
                    }
                }
            }
        }
    }
    
    private func updateAudio() {
        if manicGame.gameType == ._3ds {
            if manicGame.volume {
                if Settings.defalut.respectSilentMode, muteSwitchMonitor.isMonitoring, muteSwitchMonitor.isMuted {
                    threeDSCore?.disableVolume()
                } else {
                    threeDSCore?.enableVolume()
                }
            } else {
                threeDSCore?.disableVolume()
            }
        } else if manicGame.gameType.isLibretroType {
            if Settings.defalut.respectSilentMode, muteSwitchMonitor.isMonitoring, muteSwitchMonitor.isMuted {
                LibretroCore.sharedInstance().mute(false)
            } else {
                LibretroCore.sharedInstance().mute(manicGame.volume)
            }
        } else {
            if let manicEmuCore = manicEmuCore {
                if manicGame.volume && !manicEmuCore.audioManager.isEnabled {
                    manicEmuCore.audioManager.isEnabled = true
                } else if manicEmuCore.audioManager.isEnabled && !manicGame.volume {
                    manicEmuCore.audioManager.isEnabled = false
                }
            }
        }
    }
    
    private func updateCheatCodes(firstInit: Bool = false) {
        if manicGame.gameType == ._3ds {
            let identifier = manicGame.identifierFor3DS
            if identifier != 0 {
                var cheatsTxt = ""
                var enableCheats: [String] = []
                for cheatCode in manicGame.gameCheats {
                    cheatsTxt += "[\(cheatCode.name)]\n\(cheatCode.code)\n"
                    if cheatCode.activate {
                        enableCheats.append("[\(cheatCode.name)]")
                    }
                }
                if !cheatsTxt.isEmpty  {
                    ThreeDS.setupCheats(identifier: identifier, cheatsTxt: cheatsTxt, enableCheats: enableCheats)
                    if enableCheats.count > 0 {
                        UIView.makeToast(message: R.string.localizable.gameCheatActivateSuccess(String.successMessage(from: enableCheats)))
                    }
                }
            }
        } else if manicGame.gameType == .psp {
            if let gameCode = manicGame.gameCodeForPSP {
                var cheatsTxt = ""
                for cheatCode in manicGame.gameCheats {
                    if cheatCode.activate {
                        cheatsTxt += "_C1 \(cheatCode.name)\n\(cheatCode.code)\n"
                    }
                }
                let cheatFilePath = Constants.Path.PSPCheat(gameCode: gameCode)
                if firstInit {
                    LibretroCore.sharedInstance().updatePSPCheat(cheatsTxt, cheatFilePath: cheatFilePath, reloadGame: false)
                    lastPSPCheatCode = cheatsTxt
                } else if cheatsTxt != lastPSPCheatCode {
                    LibretroCore.sharedInstance().updatePSPCheat(cheatsTxt, cheatFilePath: cheatFilePath, reloadGame: true)
                    lastPSPCheatCode = cheatsTxt
                }
            }
        } else if manicGame.gameType.isLibretroType {
            DispatchQueue.main.asyncAfter(delay: manicGame.isPicodriveCore && firstInit ? 1 : 0) {
                LibretroCore.sharedInstance().resetCheatCode()
                for (index, cheatCode) in self.manicGame.gameCheats.enumerated() {
                    if cheatCode.activate {
                        if CheatType(cheatCode.type) == .actionReplay16, self.manicGame.isPicodriveCore, cheatCode.code.count > 6 {
                        //MD不支持0123456789格式的作弊码，需要转换成012345:6789格式
                            let processedCode = cheatCode.code[...5] + ":" + cheatCode.code[6...]
                            LibretroCore.sharedInstance().addCheatCode(String(processedCode), index: UInt32(index), enable: true)
                        } else {
                            LibretroCore.sharedInstance().addCheatCode(cheatCode.code, index: UInt32(index), enable: true)
                        }
                    }
                }
            }
            
        } else {
            if let manicEmuCore = manicEmuCore {
                let lastState = manicEmuCore.state
                pauseEmulation()
                var success = [String]()
                for cheatCode in manicGame.gameCheats {
                    if cheatCode.activate {
                        if manicEmuCore.cheatCodes[cheatCode.code] == nil {
                            do {
                                try manicEmuCore.activate(Cheat(code: cheatCode.code, type: CheatType(cheatCode.type)))
                                success.append(cheatCode.name)
                            } catch {
                                UIView.makeToast(message: R.string.localizable.gameCheatActivateFailed(cheatCode.name))
                            }
                        }
                    } else {
                        manicEmuCore.deactivate(Cheat(code: cheatCode.code, type: CheatType(cheatCode.type)))
                    }
                }
                if success.count > 0 {
                    UIView.makeToast(message: R.string.localizable.gameCheatActivateSuccess(String.successMessage(from: success)))
                }
                if lastState == .running {
                    resumeEmulationAndHandleAudio()
                }
            }
        }
    }
    
    private func updateFilter() {
        guard manicGame.gameType != ._3ds else { return }
        
        if manicGame.gameType.isLibretroType {
            //Libretro filterName是滤镜的路径
            LibretroCore.sharedInstance().setShader(manicGame.libretroShaderPath)
        } else {
            func handleGameViewFilter(_ newFilter: CIFilter?, handleGameView: GameView) {
                if let newFilter = newFilter {
                    //新增滤镜
                    if let oldFilter = handleGameView.filter as? FilterChain {
                        var filters = oldFilter.inputFilters.filter { !($0 is CRTFilter) && $0.name !=  "CIColorCube" }
                        filters.append(newFilter)
                        handleGameView.filter = FilterChain(filters: filters)
                    } else {
                        handleGameView.filter = newFilter
                    }
                } else {
                    //移除滤镜
                    if let oldFilter = handleGameView.filter {
                        if let oldFilter = oldFilter as? FilterChain {
                            let filters = oldFilter.inputFilters.filter { !($0 is CRTFilter) && $0.name !=  "CIColorCube" }
                            handleGameView.filter = FilterChain(filters: filters)
                        } else {
                            handleGameView.filter = nil
                        }
                    }
                }
            }
            
            if let filterName = self.manicGame.filterName {
                if PurchaseManager.isMember, Settings.defalut.airPlay, ExternalSceneDelegate.isAirPlaying {
                    if let airPlayGameView = ExternalSceneDelegate.airPlayViewController?.gameView {
                        handleGameViewFilter(FilterManager.find(name: filterName), handleGameView: airPlayGameView)
                    }
                } else {
                    gameViews.forEach { gameView in
                        handleGameViewFilter(FilterManager.find(name: filterName), handleGameView: gameView)
                    }
                }
            } else {
                if PurchaseManager.isMember, Settings.defalut.airPlay, ExternalSceneDelegate.isAirPlaying {
                    if let airPlayGameView = ExternalSceneDelegate.airPlayViewController?.gameView {
                        handleGameViewFilter(nil, handleGameView: airPlayGameView)
                    }
                } else {
                    gameViews.forEach { gameView in
                        handleGameViewFilter(nil, handleGameView: gameView)
                    }
                }
            }
        }
    }
    
    //加载默认配置
    private func loadConfig() {
        //加载存档
        if let saveState = loadSaveState {
            DispatchQueue.main.asyncAfter(delay: 1) { [weak self] in
                guard let self = self else { return }
                //模拟器如果没有加载好 直接加载存档可能会导致闪退
                if self.manicGame.gameType == ._3ds {
                    DispatchQueue.main.asyncAfter(delay: 5) {
                        self.quickLoadStateFor3DS(saveState)
                    }
                } else if self.manicGame.gameType.isLibretroType {
                    self.quickLoadStateForLibretro(saveState)
                } else {
                    self.quickLoadStateAndResume(saveState)
                }
            }
        }
        //设置触感
        updateHaptic()
        
        DispatchQueue.main.asyncAfter(delay: (manicGame.gameType == ._3ds || manicGame.gameType == .psp) ? 0 : 1) { [weak self] in
            //加载作弊码
            self?.updateCheatCodes(firstInit: true)
            //设置AirPlay
            self?.updateAirPlay()
        }
        if manicGame.gameType == .psp {
            LibretroCore.sharedInstance().setPSPResolution(UInt32(manicGame.resolution == .undefine ? 1 : manicGame.resolution.rawValue), reload: false)
            LibretroCore.sharedInstance().setPSPLanguage(UInt32(manicGame.region))
        } else if manicGame.gameType == .nes {
            LibretroCore.sharedInstance().updateConfig("Nestopia", key: "nestopia_aspect", value: "uncorrected", reload: false)
        } else if manicGame.gameType == .snes {
            LibretroCore.sharedInstance().updateConfig("Snes9x", key: "snes9x_aspect", value: "uncorrected", reload: false)
            LibretroCore.sharedInstance().updateConfig("Snes9x", key: "snes9x_block_invalid_vram_access", value: "disabled", reload: false)
        } else if manicGame.isPicodriveCore {
            LibretroCore.sharedInstance().updateConfig("PicoDrive", key: "picodrive_input1", value: "6 button pad", reload: false)
            LibretroCore.sharedInstance().updateConfig("PicoDrive", key: "picodrive_input2", value: "6 button pad", reload: false)
        } else if manicGame.gameType == .ss {
            LibretroCore.sharedInstance().updateConfig("Yabause", key: "yabause_addon_cartridge", value: "4M_ram", reload: false)
            LibretroCore.sharedInstance().updateConfig("Beetle Saturn", key: "beetle_saturn_cart", value: "Extended RAM (4MB)", reload: false)
            LibretroCore.sharedInstance().updateConfig("Beetle Saturn", key: "beetle_saturn_region", value: Constants.Strings.SaturnConsoleLanguage[manicGame.region], reload: false)
            LibretroCore.sharedInstance().updateConfig("Beetle Saturn", key: "beetle_saturn_horizontal_overscan", value: "20", reload: false)
        } else if manicGame.gameType == .ds {
            if manicGame.region != 0 {
                manicEmuCore?.manicCore.emulatorConnector.setExtraParameters?(["language": manicGame.region - 1])
            }
        } else if manicGame.gameType == .gbc || manicGame.gameType == .gb {
            manicEmuCore?.manicCore.emulatorConnector.setExtraParameters?(["palette": manicGame.pallete.rawValue])
        } else if manicGame.gameType == .n64 {
            updateN64Resolution(manicGame.resolution, reload: false)
            LibretroCore.sharedInstance().updateConfig("Mupen64Plus-Next", key: "mupen64plus-pak1", value: manicGame.hasTransferPak ? "transfer" : "memory", reload: false)
        }
        
        //配置静音模式
        if manicGame.gameType.isLibretroType {
            LibretroCore.sharedInstance().setRespectSilentMode(Settings.defalut.respectSilentMode)
        } else if manicGame.gameType == ._3ds {
            //不需要配置
        } else {
            manicEmuCore?.audioManager.followSilentMode = Settings.defalut.respectSilentMode
        }
        if (manicGame.gameType.isLibretroType || manicGame.gameType == ._3ds) && Settings.defalut.respectSilentMode {
            //监听静音键
            muteSwitchMonitor.startMonitoring { [weak self] isMute in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.updateAudio()
                }
            }
        }
    }
    
    //更新皮肤
    private func updateSkin() {
        
        func setPrefferedSkin() {
            showSkinButtons()
            isFullScreen = false
            var initGameType: GameType?
            var supportGameTypes: [GameType]?
            if manicGame.gameType.reuseSkinGameType.count > 1 {
                initGameType = manicGame.gameType
                supportGameTypes = manicGame.gameType.reuseSkinGameType
            }
            if UIDevice.isLandscape {
                //设置横屏皮肤
                if let skin = manicGame.landscapeSkin, var controllerSkin = ControllerSkin(fileURL: skin.fileURL, initGameType: initGameType, supportGameTypes: supportGameTypes) {
                    if enableSwapScreen() {
                        controllerSkin.isSwapScreen = manicGame.swapScreen
                    }
                    controllerView.controllerSkin = controllerSkin
                } else if let skin = SkinConfig.prefferedLandscapeSkin(gameType: manicGame.gameType), var controllerSkin = ControllerSkin(fileURL: skin.fileURL, initGameType: initGameType, supportGameTypes: supportGameTypes) {
                    if enableSwapScreen() {
                        controllerSkin.isSwapScreen = manicGame.swapScreen
                    }
                    controllerView.controllerSkin = controllerSkin
                }
            } else {
                //设置竖屏皮肤
                if let skin = manicGame.portraitSkin, var controllerSkin = ControllerSkin(fileURL: skin.fileURL, initGameType: initGameType, supportGameTypes: supportGameTypes) {
                    if enableSwapScreen() {
                        controllerSkin.isSwapScreen = manicGame.swapScreen
                    }
                    controllerView.controllerSkin = controllerSkin
                } else if let skin = SkinConfig.prefferedPortraitSkin(gameType: manicGame.gameType), var controllerSkin = ControllerSkin(fileURL: skin.fileURL, initGameType: initGameType, supportGameTypes: supportGameTypes) {
                    if enableSwapScreen() {
                        controllerSkin.isSwapScreen = manicGame.swapScreen
                    }
                    controllerView.controllerSkin = controllerSkin
                }
            }
        }
        
#if !targetEnvironment(simulator)
        if manicGame.forceFullSkin || (ExternalGameControllerUtils.shared.linkedControllers.count > 0 && Settings.defalut.fullScreenWhenConnectController) {
            //设置全屏皮肤
            let realm = Database.realm
            if let coreName = manicEmuCore?.manicCore.name,
               let skin = realm.objects(Skin.self).where({ $0.fileName == "\(coreName)_FLEX.manicskin" }).first,
                let skinUrl = skin.skinData?.filePath,
               var controllerSkin = ControllerSkin(fileURL: skinUrl) {
                if enableSwapScreen() {
                    controllerSkin.isSwapScreen = manicGame.swapScreen
                }
                isFullScreen = true
                controllerView.controllerSkin = controllerSkin
                hideSkinButtons()
            } else {
                setPrefferedSkin()
            }
        } else {
            setPrefferedSkin()
        }
#else
        setPrefferedSkin()
#endif
        
        //设置皮肤控制器的玩家角色
        controllerView.playerIndex = PlayViewController.skinControllerPlayerIndex
        //更新Libretro的画面
        updateLibretroViews()
        //尝试加载滤镜
        updateFilter()
        //尝试添加屏幕按钮
        updateFunctionButton()
        if manicGame.gameType == .ds || manicGame.gameType == ._3ds {
            updateFunctionButtonContainer()
        }
        //更新3DS画面视图
        update3DSViews()
    }
    
    /// 按照配置开始强制旋转屏幕
    private func startOrientation() {
        if #available(iOS 16.0, *) {
            self.setNeedsUpdateOfSupportedInterfaceOrientations()
            if let scene = ApplicationSceneDelegate.applicationScene {
                if manicGame.orientation == .landscape {
                    scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS.init(interfaceOrientations: .landscapeRight))
                } else if manicGame.orientation == .portrait {
                    scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS.init(interfaceOrientations: .portrait))
                }
            }
        } else {
            if manicGame.orientation == .landscape {
                UIDevice.current.setValue(NSNumber(integerLiteral: UIInterfaceOrientation.landscapeRight.rawValue), forKey: "orientation")
            } else if manicGame.orientation == .portrait {
                UIDevice.current.setValue(NSNumber(integerLiteral: UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
            }
        }
        setOrientationConfig()
    }
    
    
    /// 设置游戏页面的旋转配置

    private func setOrientationConfig() {
        AppDelegate.orientation = {
            if manicGame.orientation == .landscape {
                return .landscape
            } else if manicGame.orientation == .portrait {
                return .portrait
            } else {
                return UIDevice.isPad ? .all : .allButUpsideDown
            }
        }()
    }
    
    /// 恢复默认旋转配置
    private func resetOrientationConfig() {
        AppDelegate.orientation = UIDevice.isPad ? .all : .portrait
    }
    
    ///固定旋转配置
    private func fixedOrientationConfig() {
        switch UIDevice.currentOrientation {
        case .unknown: break
        case .portrait:
            AppDelegate.orientation = .portrait
        case .portraitUpsideDown:
            AppDelegate.orientation = .portraitUpsideDown
        case .landscapeLeft:
            AppDelegate.orientation = .landscapeLeft
        case .landscapeRight:
            AppDelegate.orientation = .landscapeRight
        @unknown default:
            break
        }
    }
    
    /// 更新震感
    private func updateHaptic() {
        switch manicGame.haptic {
        case .off:
            controllerView.isButtonHaptic = false
            controllerView.isThumbstickHaptic = false
        default:
            controllerView.isButtonHaptic = true
            controllerView.isThumbstickHaptic = true
        }
        
        switch manicGame.haptic {
        case .soft:
            controllerView.hapticFeedbackStyle = .soft
        case .light:
            controllerView.hapticFeedbackStyle = .light
        case .medium:
            controllerView.hapticFeedbackStyle = .medium
        case .heavy:
            controllerView.hapticFeedbackStyle = .heavy
        case .rigid:
            controllerView.hapticFeedbackStyle = .rigid
        default:
            break
        }
    }
    
    /// 更新AirPlay
    private func updateAirPlay() {
        guard manicGame.gameType != ._3ds else { return }
        
        if manicGame.gameType.isLibretroType {
            if PurchaseManager.isMember, Settings.defalut.airPlay, ExternalSceneDelegate.isAirPlaying {
                //执行全屏投屏
                if let airPlayViewController = ExternalSceneDelegate.airPlayViewController, let gameMetalView {
                    gameMetalView.removeFromSuperview()
                    airPlayViewController.addLibretroView(gameMetalView, dimensions: manicEmuCore?.videoManager.videoFormat.dimensions ?? CGSize(width: 480, height: 360))
                }
            } else {
                //不执行全屏投屏
                if let _ = ExternalSceneDelegate.airPlayViewController, let gameMetalView {
                    gameMetalView.removeFromSuperview()
                    view.insertSubview(gameMetalView, belowSubview: controllerView)
                    updateLibretroViews()
                }
            }
        } else {
            if let traits = self.controllerView.controllerSkinTraits,
               let supportedTraits = self.controllerView.controllerSkin?.supportedTraits(for: traits),
               let screens = self.controllerView.controllerSkin?.screens(for: supportedTraits) {
                for (screen, gameView) in zip(screens, self.gameViews) {
                    if PurchaseManager.isMember, Settings.defalut.airPlay, ExternalSceneDelegate.isAirPlaying {
                        //开启了AirPlay全屏设置，并且当前处于AirPlay连接中 将所有游戏画面都暂停 除了NDS的副屏
                        gameView.isEnabled = screen.isTouchScreen
                        if gameView == self.gameView {
                            gameView.isAirPlaying = true
                            gameView.isHidden = false
                        }
                        
                        //设置AirPlay屏幕上的游戏画面 NDS的触屏就不需要加入到AirPlay显示上
                        if !screen.isTouchScreen {
                            if let airPlayViewController = ExternalSceneDelegate.airPlayViewController {
                                let newGameView = GameView()
                                newGameView.update(for: screen)
                                newGameView.frame = gameView.bounds
                                self.manicEmuCore?.add(newGameView)
                                airPlayViewController.addGameView(newGameView)
                            }
                        }
                        
                    } else {
                        //正常情况下
                        gameView.isEnabled = true
                        gameView.isAirPlaying = false
                        gameView.isHidden = false

                        //移除AirPlay上的画面
                        if let airPlayViewController = ExternalSceneDelegate.airPlayViewController, let airPlayGameView = airPlayViewController.gameView {
                            self.manicEmuCore?.remove(airPlayGameView)
                        }
                    }
                }
                self.updateFilter()
            }
        }
    }
    
    private func updateFunctionButton() {
        functionButtonContainer.subviews.forEach { $0.removeFromSuperview() }
        if manicGame.gameType == ._3ds && UIDevice.isPad {
            return
        }
        if let controllerSkin = controllerView.controllerSkin {
            if let skin = Database.realm.objects(Skin.self).first(where: { $0.identifier == controllerSkin.identifier }) {
                if skin.skinType == .default {
                    //当前使用的是默认皮肤 则添加功能按钮
                    let settings = Settings.defalut
                    let functionButtonCount = settings.displayGamesFunctionCount
                    guard functionButtonCount > 0 else { return }
                    for (index, settingTypeValue) in settings.gameFunctionList.prefix(functionButtonCount).enumerated() {
                        if let settingType = GameSetting.ItemType(rawValue: settingTypeValue) {
                            var gameSetting = GameSetting(type: settingType)
                            gameSetting.volumeOn = manicGame.volume
                            gameSetting.hapticType = manicGame.haptic
                            let button = UIImageView(image: gameSetting.image.withRenderingMode(.alwaysTemplate).applySymbolConfig(color: Constants.Color.LabelTertiary))
                            button.tintColor = Constants.Color.LabelTertiary
                            button.contentMode = .center
                            button.isUserInteractionEnabled = true
                            button.enableInteractive = true
                            functionButtonContainer.addSubview(button)
                            button.snp.makeConstraints { make in
                                if manicGame.gameType == .ds || manicGame.gameType == ._3ds {
                                    if UIDevice.isPhone {
                                        make.width.equalTo(31)
                                        make.height.equalToSuperview().dividedBy(2)
                                        if index == 0 {
                                            make.leading.equalToSuperview()
                                            make.top.equalToSuperview()
                                        } else if index == 1 {
                                            make.leading.equalToSuperview()
                                            make.top.equalTo(functionButtonContainer.subviews[index - 1].snp.bottom)
                                        } else if index == 2 {
                                            make.trailing.equalToSuperview()
                                            make.top.equalToSuperview()
                                        } else if index == 3 {
                                            make.trailing.equalToSuperview()
                                            make.top.equalTo(functionButtonContainer.subviews[index - 1].snp.bottom)
                                        }
                                    } else {
                                        make.width.equalTo(50)
                                        make.top.bottom.equalToSuperview()
                                        if index == 0 {
                                            make.leading.equalToSuperview()
                                        } else if index == 1 {
                                            make.leading.equalTo(functionButtonContainer.subviews[index-1].snp.trailing)
                                        } else if index == 2 {
                                            make.trailing.equalToSuperview().inset(50)
                                        } else if index == 3 {
                                            make.trailing.equalToSuperview()
                                        }
                                    }
                                } else {
                                    if index == 0 {
                                        make.leading.equalToSuperview()
                                    } else {
                                        make.leading.equalTo(functionButtonContainer.subviews[index-1].snp.trailing)
                                    }
                                    make.top.bottom.equalToSuperview()
                                    if index == functionButtonCount-1 && functionButtonCount == Constants.Numbers.GameFunctionButtonCount {
                                        make.trailing.equalToSuperview()
                                    }
                                    make.width.equalToSuperview().dividedBy(Constants.Numbers.GameFunctionButtonCount)
                                }
                            }
                            button.addTapGesture { [weak self, weak button] gesture in
                                guard let self = self else { return }
                                var newGameSetting = GameSetting(type: settingType)
                                switch settingType {
                                case .volume:
                                    newGameSetting.volumeOn = !self.manicGame.volume
                                    button?.image = newGameSetting.image.applySymbolConfig(color: Constants.Color.LabelTertiary)
                                case .fastForward:
                                    newGameSetting.fastForwardSpeed = self.manicGame.speed.next
                                case .haptic:
                                    newGameSetting.hapticType = self.manicGame.haptic.next
                                case .orientation:
                                    newGameSetting.orientation = self.manicGame.orientation.next
                                case .resolution:
                                    newGameSetting.resolution = self.manicGame.resolution.next
                                case .palette:
                                    newGameSetting.palette = self.manicGame.pallete.next
                                case .toggleFullscreen:
                                    newGameSetting.isFullScreen = !self.manicGame.forceFullSkin
                                default:
                                    break
                                }
                                self.handleMenuGameSetting(newGameSetting, nil)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func updateFunctionButtonContainer() {
        if (manicGame.gameType == .ds || (UIDevice.isPhone && manicGame.gameType == ._3ds)) &&  UIDevice.isPhone {
            functionButtonContainer.snp.remakeConstraints { make in
                if gameViews.count > 1 {
                    //iPhone ds布局比较特殊
                    if UIDevice.isLandscape {
                        make.leading.equalTo(gameViews[0]).inset(-33)
                        make.trailing.equalTo(gameViews[1]).inset(-33)
                        make.top.equalToSuperview()
                    } else {
                        make.leading.trailing.equalTo(gameViews[1]).inset(-33)
                        make.top.equalTo(gameViews[1])
                    }
                    
                    if manicGame.gameType == ._3ds {
                        if let displayType = controllerView.controllerSkinTraits?.displayType, displayType == .standard {
                            //小屏幕
                            make.height.equalTo(80)
                        } else {
                            //大屏幕
                            make.height.equalTo(96)
                        }
                    } else {
                        if let displayType = controllerView.controllerSkinTraits?.displayType, displayType == .standard, !UIDevice.isLandscape {
                            make.height.equalTo(87)
                        } else {
                            make.height.equalTo(113)
                        }
                    }
                }
            }
        }
    }
    
    private func update3DSViews() {
        guard manicGame.gameType == ._3ds else { return }
        guard let controllerSkin = controllerView.controllerSkin as? ControllerSkin else { return }
        guard let frames = controllerSkin.getFrames() else { return }
        guard let touchGameViewFrame = frames.touchGameViewFrame else { return }
        
        Log.debug("更新3DS视图 frames:\(frames)")
        if let _ = gameMetalView {
            //渲染视图已经生成
            threeDSCore?.updateViews(topRect: frames.mainGameViewFrame,
                                     bottomRect: touchGameViewFrame)
        } else {
            threeDSCore = self.manicEmuCore?.manicCore.emulatorConnector as? ThreeDSEmulatorBridge
            gameMetalView = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
            guard let gameMetalView else { return }
            self.view.insertSubview(gameMetalView, belowSubview: controllerView)
            gameMetalView.snp.makeConstraints { make in
                make.edges.equalTo(controllerView)
            }
            threeDSCore?.start(withGameURL: manicGame.romUrl,
                               metalView: gameMetalView as! MTKView,
                               metalViewFrame: frames.skinFrame,
                               topRect: frames.mainGameViewFrame,
                               bottomRect: touchGameViewFrame,
                               mute: !manicGame.volume,
                               resolution: manicGame.resolution,
                               jit: LibretroCore.jitAvailable() ? manicGame.jit : false,
                               accurateShaders: manicGame.accurateShaders,
                               language: manicGame.region-1,
                               renderRightEye: manicGame.renderRightEye)
            threeDSCore?.openKeyboardAction { hintText, keyboardType, maxTextSize in
                ThreeDSKeyboardView.show(hintText: hintText, keyboardType: keyboardType, maxTextSize: maxTextSize)
            }
        }
    }
    
    private func updateLibretroViews() {
        guard manicGame.gameType.isLibretroType else { return }
        if let gameMetalView {
            if gameMetalView.superview == view {
                gameMetalView.snp.remakeConstraints { make in
                    make.edges.equalTo(gameView)
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(delay: 0.35) { [weak self] in
                guard let self = self else { return }
                let vc = LibretroCore.sharedInstance().start()
                gameMetalView = vc.view
                guard let gameMetalView else { return }
                self.view.insertSubview(gameMetalView, belowSubview: controllerView)
                gameMetalView.snp.makeConstraints { make in
                    make.edges.equalTo(self.gameView)
                }
                gameMetalView.isHidden = true
                if let corePath = self.manicGame.libretroCorePath {
                    var compltion: (([AnyHashable: Any]?)-> Void)? = nil
                    if manicGame.gameType == .psp, manicGame.gameCodeForPSP == nil {
                        compltion = { [weak self] gameInfo in
                            guard let self = self else { return }
                            if let gameInfo {
                                self.manicGame.setExtras(gameInfo)
                            }
                        }
                    }
                    LibretroCore.sharedInstance().loadGame(manicGame.romUrl.path, corePath: corePath, completion: compltion)
                    DispatchQueue.main.asyncAfter(delay: 0.5) { [weak self] in
                        guard let self = self else { return }
                        self.gameMetalView?.isHidden = false
                        self.updateFilter()
                        self.updateAirPlay()
                    }
                }
            }
        }
    }
    
    private func snapShotFor3DS(topOnly: Bool = false) -> [UIImage]? {
        guard let controllerSkin = controllerView.controllerSkin as? ControllerSkin else { return nil }
        guard let frames = controllerSkin.getFrames() else { return nil }
        guard let touchGameViewFrame = frames.touchGameViewFrame else { return nil }
        let skinFrame = frames.skinFrame
        let mainGameViewFrame = frames.mainGameViewFrame
        let topRect = CGRectMake(skinFrame.minX + mainGameViewFrame.minX, skinFrame.minY + mainGameViewFrame.minY, mainGameViewFrame.width, mainGameViewFrame.height)
        let bottomRect = CGRectMake(skinFrame.minX + touchGameViewFrame.minX, skinFrame.minY + touchGameViewFrame.minY, touchGameViewFrame.width, touchGameViewFrame.height)
        let screenImage = view.asImage()
        if topOnly {
            return [screenImage.cropped(to: topRect)]
        } else {
            return [screenImage.cropped(to: topRect), screenImage.cropped(to: bottomRect)]
        }
    }
    
    private func hideSkinButtons() {
        guard isFullScreen else { return }
        //隐藏按键 除了menu和flex
        for view in controllerView.contentView.subviews {
            if let buttonsDynamicEffectView = view as? ButtonsDynamicEffectView {
                for dynamicEffectView in  buttonsDynamicEffectView.itemViews {
                    let item = dynamicEffectView.item
                    if item.kind == .button, let input = item.inputs.allInputs.first, (input.stringValue == "menu" || input.stringValue == "flex") {
                        //不隐藏
                        dynamicEffectView.alpha = 0.3
                    } else {
                        dynamicEffectView.isHidden = true
                    }
                }
            } else if String(describing: type(of: view)) == "TouchInputView" {
                //触摸视图不隐藏
            } else {
                view.isHidden = true
            }
        }
    }
    
    private func showSkinButtons() {
        guard isFullScreen else { return }
        
        for view in controllerView.contentView.subviews {
            if let buttonsDynamicEffectView = view as? ButtonsDynamicEffectView {
                for dynamicEffectView in  buttonsDynamicEffectView.itemViews {
                    dynamicEffectView.isHidden = false
                    dynamicEffectView.alpha = 1
                }
            } else if String(describing: type(of: view)) == "InputDebugView" {
                //debug view不显示
            } else {
                view.isHidden = false
            }
        }
    }
    
    private func enableSwapScreen() -> Bool {
        if manicGame.gameType == .ds || manicGame.gameType == ._3ds {
            return true
        }
        return false
    }
    
    private func updateN64Resolution(_ resolution: GameSetting.Resolution, reload: Bool) {
        let options = ["640x480", "960x720", "1280x960", "1440x1080", "1600x1200", "1920x1440", "2240x1680", "2560x1920", "2880x2160", "3520x2640"]
        var option = "640x480"
        if resolution != .undefine {
            option = options[resolution.rawValue - 1]
        }
        LibretroCore.sharedInstance().updateConfig("Mupen64Plus-Next", key: "mupen64plus-43screensize", value: option, reload: reload)
    }
}

//MARK: GameViewControllerDelegate代理
extension PlayViewController: GameViewControllerDelegate {
    
    func gameViewController(_ gameViewController: GameViewController, optionsFor game: GameBase) -> [EmulatorCore.Option: Any] {
        var options: [EmulatorCore.Option: Any] = [.metal: false]
        if #available(iOS 18, macOS 15, *), ProcessInfo.processInfo.isiOSAppOnMac {
            options[.metal] = true
        }
        return options
    }
    
    func gameViewControllerShouldResume(_ gameViewController: GameViewController) -> Bool {
        if SheetProvider.find(identifier: Constants.Strings.PlayPurchaseAlertIdentifier).count > 0 {
            return false
        }
        return (GameSettingView.isShow || GameInfoView.isShow || CheatCodeListView.isShow || SkinSettingsView.isShow || FilterSelectionView.isShow || ControllersSettingView.isShow || GameSettingView.isEditingShow || WebViewController.isShow || FlexSkinSettingViewController.isShow) ? false : true
    }
    
}

//MARK: 公开方法
extension PlayViewController {
    static var isGaming: Bool { currentPlayViewController != nil }
    
    static var playingGameType: GameType {
        if let currentPlayViewController {
            return currentPlayViewController.manicGame.gameType
        }
        return .unknown
    }
}
