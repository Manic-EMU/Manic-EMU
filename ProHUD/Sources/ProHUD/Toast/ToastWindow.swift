//
//  ToastWindow.swift
//  
//
//  Created by xaoxuu on 2022/9/3.
//

import UIKit

class ToastWindow: Window {
    
    var toast: ToastTarget
    
    var maxY = CGFloat(0)
    
    init(toast: ToastTarget) {
        self.toast = toast
        super.init(frame: .zero)
        windowScene = AppContext.windowScene
        toast.window = self
        windowLevel = .phToast
        layer.shadowRadius = 8
        layer.shadowOffset = .init(width: 0, height: 5)
        layer.shadowOpacity = 0.2
        isHidden = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath.init(rect: bounds).cgPath
    }
    
}

extension ToastTarget {
    func getContextWindows() -> [ToastWindow] {
        guard let windowScene = windowScene ?? AppContext.windowScene else {
            return []
        }
        return AppContext.toastWindows[windowScene] ?? []
    }
    func setContextWindows(_ windows: [ToastWindow]) {
        guard let windowScene = windowScene ?? AppContext.windowScene else {
            return
        }
        AppContext.toastWindows[windowScene] = windows
    }
}
