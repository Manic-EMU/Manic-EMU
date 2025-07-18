//
//  System.swift
//  Delta
//
//  Created by Riley Testut on 4/30/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import ManicEmuCore
import GBADeltaCore
import GBCDeltaCore
import MelonDSDeltaCore

enum System: CaseIterable
{
    case n64
    case ss
    case ms
    case gg
    case sg1000
    case _32x
    case mcd
    case md
    case psp
    case _3ds
    case ds
    case gba
    case gbc
    case gb
    case nes
    case snes

    static var registeredSystems: [System] {
        let systems = System.allCases.filter { ManicEmu.registeredCores.keys.contains($0.gameType) }
        return systems
    }
    
    static var allCores: [ManicEmuCoreProtocol] {
        return [NES.core, SNES.core, ThreeDS.core, GBC.core, GBA.core, MelonDS.core, PSP.core, MD.core, MCD.core, S2X.core, SG1000.core, GG.core, MS.core, SS.core, N64.core, GB.core]
    }
}

extension System {
    
    var gameType: ManicEmuCore.GameType {
        switch self
        {
        case .nes: return .nes
        case .snes: return .snes
        case ._3ds: return ._3ds
        case .gbc: return .gbc
        case .gb: return .gb
        case .gba: return .gba
        case .ds: return .ds
        case .psp: return .psp
        case .md: return .md
        case .mcd: return .mcd
        case ._32x: return ._32x
        case .sg1000: return .sg1000
        case .gg: return .gg
        case .ms: return .ms
        case .ss: return .ss
        case .n64: return .n64
        }
    }
}
