//
//  TKSwitchExtensions.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/3/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//

import TKSwitcherCollection

extension TKBaseSwitch {
    @discardableResult
    func onChange(handler: ((_ value: Bool) -> Void)? = nil) -> Self {
        self.valueChange = handler
        return self
    }
    
    func onDisableTap(handler: (()->Void)? = nil) {
        self.disableTap = handler
    }
}
