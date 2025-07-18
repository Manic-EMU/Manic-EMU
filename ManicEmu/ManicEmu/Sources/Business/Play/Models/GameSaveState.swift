//
//  GameSaveState.swift
//  ManicEmu
//
//  Created by Max on 2025/1/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import RealmSwift
import IceCream
import Device

extension GameSaveState: CKRecordConvertible & CKRecordRecoverable { }

class GameSaveState: Object {
    ///主键 rom的id+时间戳 xxx_2025-03-03_12-00-00 3DS的话就是存档的名称
    @Persisted(primaryKey: true) var name: String
    ///状态存档类型
    @Persisted var type: GameSaveStateType
    ///时间日期
    @Persisted var date: Date
    ///截图数据
    @Persisted var stateCover: CreamAsset?
    ///状态存档内容
    @Persisted var stateData: CreamAsset?
    ///生成存档的设备
    @Persisted var device: String = Device.version().rawValue
    ///生成存档的系统版本
    @Persisted var osVersion: String = UIDevice.current.systemVersion
    ///用于iCloud同步删除
    @Persisted var isDeleted: Bool = false
    
    ///该即时存档是否适配本系统
    var isCompatible: Bool {
        if device == Device.version().rawValue && osVersion == UIDevice.current.systemVersion {
            return true
        }
        return false
    }
    
    var gameSaveStateDeviceInfo: String {
        device + " " + osVersion
    }
    
    var currentDeviceInfo: String {
        Device.version().rawValue + " " + UIDevice.current.systemVersion
    }
}

enum GameSaveStateType: Int, PersistableEnum {
    case autoSaveState, manualSaveState
}
