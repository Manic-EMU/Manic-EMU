//
//  CloudDriveType.swift
//  CloudServiceKitExample
//
//  Created by alexiscn on 2021/9/18.
//

import Foundation
import UIKit

enum CloudDriveType: String, Codable, CaseIterable, Hashable {
    case aliyunDrive
    case baiduPan
    case box
    case dropbox
    case googleDrive
    case oneDrive
    case pCloud
    case drive115
    case drive123
    
    var title: String {
        switch self {
        case .aliyunDrive: return "Aliyun Drive"
        case .baiduPan: return "Baidu Pan"
        case .box: return "Box"
        case .dropbox: return "Dropbox"
        case .googleDrive: return "Google Drive"
        case .oneDrive: return "OneDrive"
        case .pCloud: return "pCloud"
        case .drive115: return "115"
        case .drive123: return "123Pan"
        }
    }
    
    var image: UIImage? {
        switch self {
        case .aliyunDrive: return UIImage(named: "aliyundrive")
        case .baiduPan: return UIImage(named: "baidupan")
        case .box: return UIImage(named: "box")
        case .dropbox: return UIImage(named: "dropbox")
        case .googleDrive: return UIImage(named: "googledrive")
        case .oneDrive: return UIImage(named: "onedrive")
        case .pCloud: return UIImage(named: "pcloud")
        case .drive115: return UIImage(named: "115")
        case .drive123: return UIImage(named: "123")
        }
    }
}
