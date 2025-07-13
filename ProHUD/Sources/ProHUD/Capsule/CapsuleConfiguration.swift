//
//  CapsuleConfiguration.swift
//  
//
//  Created by xaoxuu on 2022/9/8.
//

import UIKit

public class CapsuleConfiguration: CommonConfiguration {
    
    public typealias CustomAnimateHandler = ((_ window: UIWindow, _ completion: @escaping () -> Void) -> Void)
    
    private static var customGlobalConfig: ((_ config: CapsuleConfiguration) -> Void)?
    
    public override init() {
        super.init()
        Self.customGlobalConfig?(self)
    }
    
    /// 全局共享配置（只能设置一次，影响所有实例）
    /// - Parameter callback: 配置代码
    public static func global(_ callback: @escaping (_ config: CapsuleConfiguration) -> Void) {
        customGlobalConfig = callback
    }
    
    /// 默认的持续时间
    public var defaultDuration: TimeInterval = 3
    
    override var cardMaxWidthByDefault: CGFloat { cardMaxWidth ?? 320 }
    
    override var cardMaxHeightByDefault: CGFloat { cardMaxHeight ?? 120 }
    
    /// 最小宽度(当设置了最小宽度而内容没有达到时，内容布局默认靠左)
    public var cardMinWidth: CGFloat? = nil
    
    /// 最小高度
    public var cardMinHeight = CGFloat(40)
    
    override var cardCornerRadiusByDefault: CGFloat { cardCornerRadius ?? 16 }
    
    override var cardEdgeInsetsByDefault: UIEdgeInsets {
        cardEdgeInsets ?? .init(top: 10, left: 16, bottom: 10, right: 16)
    }
    
    override var iconSizeByDefault: CGSize { iconSize ?? .init(width: 20, height: 20) }
    
    override var animateDurationForBuildInByDefault: CGFloat {
        animateDurationForBuildIn ?? 0.64
    }
    
    override var animateDurationForBuildOutByDefault: CGFloat {
        animateDurationForBuildOut ?? 0.32
    }
    
    var animateBuildIn: CustomAnimateHandler?
    public func animateBuildIn(_ handler: CustomAnimateHandler?) {
        animateBuildIn = handler
    }
    
    var animateBuildOut: CustomAnimateHandler?
    public func animateBuildOut(_ handler: CustomAnimateHandler?) {
        animateBuildOut = handler
    }
    
    
}
