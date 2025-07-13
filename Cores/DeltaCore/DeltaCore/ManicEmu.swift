//
//  Delta.swift
//  DeltaCore
//
//  Created by Riley Testut on 7/22/15.
//  Copyright © 2015 Riley Testut. All rights reserved.
//

import Foundation

#if SWIFT_PACKAGE
@_exported import CDeltaCore
#endif

extension GameType: CustomStringConvertible {
    public var description: String {
        return self.rawValue
    }
}

public extension GameType {
    static let unknown = GameType("public.aoshuang.game.unknown")
    static let notSupport = GameType("public.aoshuang.game.notSupport")
}

public struct ManicEmu
{
    public private(set) static var registeredCores = [GameType: ManicEmuCoreProtocol]()
    
    private init() { }
    
    public static func register(_ core: ManicEmuCoreProtocol) {
        self.registeredCores[core.gameType] = core
    }
    
    public static func unregister(_ core: ManicEmuCoreProtocol) {
        // Ensure another core has not been registered for core.gameType.
        guard let registeredCore = self.registeredCores[core.gameType], registeredCore == core else { return }
        self.registeredCores[core.gameType] = nil
    }
    
    public static func core(for gameType: GameType) -> ManicEmuCoreProtocol? {
        return self.registeredCores[gameType]
    }
    
    public static var coresDirectoryURL: URL = {
        let coresDirectoryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("Cores", isDirectory: true)
        try? FileManager.default.createDirectory(at: coresDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        return coresDirectoryURL
    }()
}
