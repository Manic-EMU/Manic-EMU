//
//  BaseController.swift
//
//
//  Created by xaoxuu on 2022/8/29.
//

import UIKit

open class BaseController: UIViewController {
    
    /// 需要显示到那个UIWindowScene上
    var preferredWindowScene: UIWindowScene?
    
    /// ID标识
    public var identifier = String(Date().timeIntervalSince1970)
    
    /// 执行动画的图层
    var animateLayer: CALayer?
    var animation: CAAnimation?
    
    open lazy var contentView: ContentView = ContentView()
    
    open lazy var contentMaskView: UIVisualEffectView = UIVisualEffectView()
    
    open var customView: UIView?
    
    public internal(set) var isViewAppeared = false
    
    /// 按钮事件
    var buttonEvents = [UIView: () -> Void]()
    
    public init() {
        super.init(nibName: nil, bundle: nil)
        consolePrint(self, "init")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        consolePrint("👌", self, "deinit")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    // will appear
    
    enum NavEvent: String {
        case onViewDidLoad = "onViewDidLoad"
        case onViewWillAppear = "onViewWillAppear"
        case onViewDidAppear = "onViewDidAppear"
        case onViewWillDisappear = "onViewWillDisappear"
        case onViewDidDisappear = "onViewDidDisappear"
        case onTappedBackground = "onTappedBackground"
    }
    
    var navEvents = [NavEvent: ((BaseController) -> Void)]()
    
    @discardableResult public func onViewDidLoad(_ callback: ((_ vc: BaseController) -> Void)?) -> BaseController {
        navEvents[.onViewDidLoad] = callback
        return self
    }
    
    @discardableResult public func onViewWillAppear(_ callback: ((_ vc: BaseController) -> Void)?) -> BaseController {
        navEvents[.onViewWillAppear] = callback
        return self
    }
    
    @discardableResult public func onViewDidAppear(_ callback: ((_ vc: BaseController) -> Void)?) -> BaseController {
        navEvents[.onViewDidAppear] = callback
        return self
    }
    
    @discardableResult public func onViewWillDisappear(_ callback: ((_ vc: BaseController) -> Void)?) -> BaseController {
        navEvents[.onViewWillDisappear] = callback
        return self
    }
    
    @discardableResult public func onViewDidDisappear(_ callback: ((_ vc: BaseController) -> Void)?) -> BaseController {
        navEvents[.onViewDidDisappear] = callback
        return self
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isViewAppeared = true
    }
    
}

// MARK: - 事件
extension BaseController {
    
    func addTouchUpAction(for button: UIButton, action: @escaping () -> Void) {
        button.addTarget(self, action: #selector(didTappedButton(_:)), for: .touchUpInside)
        buttonEvents[button] = action
    }

    @objc func didTappedButton(_ sender: UIButton) {
        if let ac = buttonEvents[sender] {
            ac()
        }
    }
    
    func removeTouchUpAction(for button: UIButton) {
        buttonEvents[button] = nil
    }
    
}
