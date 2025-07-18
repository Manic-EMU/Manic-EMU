//
//  Skin.swift
//  ManicEmu
//
//  Created by Max on 2025/1/19.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import RealmSwift
import ManicEmuCore
import IceCream

extension Skin: CKRecordConvertible & CKRecordRecoverable { }

enum SkinType: Int, PersistableEnum {
    case `default`, manic, delta
    
    init?(fileExtension: String) {
        if fileExtension == "manicskin" {
            self = .manic
        } else if fileExtension == "deltaskin" {
            self = .delta
        } else {
            return nil
        }
    }
    
}

///只存储用户皮肤 自带的默认皮肤不会进行存储
class Skin: Object, ObjectUpdatable {
    ///id 由文件的Hash值决定
    @Persisted(primaryKey: true) var id: String //!!!设计漏洞 不要用hash来获取皮肤 可能skin文件会被修改
    ///皮肤名称 在info.json的identifier来决定
    @Persisted var identifier: String
    ///皮肤名称 在info.json的name来决定
    @Persisted var name: String
    ///文件名（包括了扩展名）
    @Persisted var fileName: String
    ///游戏平台类型
    @Persisted var gameType: GameType
    ///皮肤类型
    @Persisted var skinType: SkinType
    ///皮肤数据
    @Persisted var skinData: CreamAsset?
    ///用于iCloud同步删除
    @Persisted var isDeleted: Bool = false
    
    ///文件是否存在
    var isFileExtsts: Bool {
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    var fileURL: URL {
        if skinType == .default, let core = gameType.manicEmuCore {
            return core.resourceBundle.url(forResource: core.name, withExtension: "manicskin")!
        } else if let filePath = skinData?.filePath {
            return filePath
        }
        //这里没什么用 如果返回下面的地址 说明该皮肤不可用 或者 是嵌入式manic皮肤
        return URL(fileURLWithPath: Constants.Path.Resource.appendingPathComponent(fileName))
    }
}
