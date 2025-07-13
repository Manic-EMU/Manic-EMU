//
//  EmulatorBase.swift
//  DeltaCore
//
//  Created by Riley Testut on 6/29/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import Foundation

@objc(MANCEmulatorBase)
public protocol EmulatorBase: NSObjectProtocol
{
    /// State
    var gameURL: URL? { get }
    
    /// System
    var frameDuration: TimeInterval { get }
    
    /// Audio
    var audioRenderer: AudioRenderProtocol? { get set }
    
    /// Video
    var videoRenderer: VideoRenderProtocol? { get set }
    
    /// Saves
    var saveUpdateHandler: (() -> Void)? { get set }
    
    
    /// Emulation State
    func start(withGameURL gameURL: URL)
    func stop()
    func pause()
    func resume()
    
    /// Game Loop
    @objc(runFrameAndProcessVideo:) func runFrame(processVideo: Bool)
    
    /// Inputs
    func activateInput(_ input: Int, value: Double, playerIndex: Int)
    func deactivateInput(_ input: Int, playerIndex: Int)
    func resetInputs()
    
    /// Save States
    @objc(saveSaveStateToURL:) func saveSaveState(to url: URL)
    @objc(loadSaveStateFromURL:) func loadSaveState(from url: URL)
    
    /// Game Games
    @objc(saveGameSaveToURL:) func saveGameSave(to url: URL)
    @objc(loadGameSaveFromURL:) func loadGameSave(from url: URL)
    
    /// Cheats
    @discardableResult func addCheatCode(_ cheatCode: String, type: String) -> Bool
    func resetCheats()
    func updateCheats()
    
    ///添加额外数据
    @objc optional func setExtraParameters(_ paramaters: [String: Any])
    
}

public extension EmulatorBase {
    func setExtraParameters(_ paramaters: [String: Any]) {}
}
