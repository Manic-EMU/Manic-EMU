//
//  ConsolePrint.swift
//  
//
//  Created by xaoxuu on 2022/8/31.
//

import Foundation

func consolePrint(_ items: Any...) {
    #if DEBUG
    guard CommonConfiguration.enablePrint else { return }
    print(">> ProHUD:", items)
    #endif
}
