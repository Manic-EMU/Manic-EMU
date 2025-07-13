//
//  Configuration.swift
//  
//
//  Created by xaoxuu on 2022/8/29.
//

import UIKit

open class CommonConfiguration: NSObject {
    
    /// 全局功能开关
    public static var isEnabled: Bool = true
    
    /// 是否允许log输出
    public static var enablePrint = true
    
    public lazy var dynamicBackgroundColor: UIColor = {
        let color = UIColor { (traitCollection: UITraitCollection) -> UIColor in
            if traitCollection.userInterfaceStyle == .dark {
                return .init(white: 0.15, alpha: 1)
            } else {
                return .init(white: 1, alpha: 1)
            }
        }
        return color
    }()
    
    /// 动态颜色（适配iOS13）
    public lazy var dynamicTextColor: UIColor = {
        let color = UIColor { (traitCollection: UITraitCollection) -> UIColor in
            if traitCollection.userInterfaceStyle == .dark {
                return .init(white: 1, alpha: 1)
            } else {
                return .init(white: 0.1, alpha: 1)
            }
        }
        return color
    }()
    
    /// 主标签文本颜色
    public lazy var primaryLabelColor: UIColor = {
        dynamicTextColor.withAlphaComponent(0.9)
    }()

    /// 次级标签文本颜色
    public lazy var secondaryLabelColor: UIColor = {
        return dynamicTextColor.withAlphaComponent(0.8)
    }()
    
    
    // MARK: 卡片样式
    /// 最大宽度（用于优化横屏或者iPad显示）
    public var cardMaxWidth: CGFloat?
    var cardMaxWidthByDefault: CGFloat {
        cardMaxWidth ?? .minimum(AppContext.appBounds.width * 0.72, 400)
    }
    
    public var cardMaxHeight: CGFloat?
    var cardMaxHeightByDefault: CGFloat {
        cardMaxHeight ?? (AppContext.appBounds.height - 100)
    }
    
    /// 卡片内边距
    public var cardEdgeInsets: UIEdgeInsets?
    var cardEdgeInsetsByDefault: UIEdgeInsets {
        cardEdgeInsets ?? .init(top: 16, left: 16, bottom: 16, right: 16)
    }
    
    /// 文字区域内边距
    public var textEdgeInsets: UIEdgeInsets = {
        .init(top: 16, left: 16, bottom: 16, right: 16)
    }()
    
    /// 卡片圆角
    public var cardCornerRadius: CGFloat?
    var cardCornerRadiusByDefault: CGFloat { cardCornerRadius ?? 16 }
    
    /// 填充：元素内部控件距离元素边界的距离
    public var padding = CGFloat(16)
    
    /// 颜色
    public var tintColor: UIColor?
    
    
    var customContentStack: ((_ stack: StackView) -> Void)?
    public func customContentStack(handler: @escaping (_ stack: StackView) -> Void) {
        customContentStack = handler
    }
    var customTextStack: ((_ stack: StackView) -> Void)?
    public func customTextStack(handler: @escaping (_ stack: StackView) -> Void) {
        customTextStack = handler
    }
    var customActionStack: ((_ stack: StackView) -> Void)?
    public func customActionStack(handler: @escaping (_ stack: StackView) -> Void) {
        customActionStack = handler
    }
    
    // MARK: 图标样式
    /// 图标尺寸
    public var iconSize: CGSize?
    
    var iconSizeByDefault: CGSize { iconSize ?? .init(width: 44, height: 44) }
    
    // MARK: 文本样式
    
    var customTextLabel: ((_ label: UILabel) -> Void)?
    
    /// 自定义文本标签（标题或正文）
    /// - Parameter handler: 自定义文本标签（标题或正文）
    public func customTextLabel(_ handler: @escaping (_ label: UILabel) -> Void) {
        customTextLabel = handler
    }
    
    var customTitleLabel: ((_ label: UILabel) -> Void)?
    
    /// 自定义标题标签
    /// - Parameter handler: 自定义标题标签
    public func customTitleLabel(_ handler: @escaping (_ label: UILabel) -> Void) {
        customTitleLabel = handler
    }
    
    /// 正文
    var customBodyLabel: ((_ label: UILabel) -> Void)?
    
    /// 自定义正文标签
    /// - Parameter handler: 自定义正文标签
    public func customBodyLabel(_ handler: @escaping (_ label: UILabel) -> Void) {
        customBodyLabel = handler
    }
    
    // MARK: 按钮样式
    var customButton: ((_ button: Button) -> Void)?
    
    /// 自定义按钮
    /// - Parameter handler: 自定义按钮
    public func customButton(handler: @escaping (_ button: Button) -> Void) {
        customButton = handler
    }
    
    // MARK: 动画
    
    public var animateDurationForBuildIn: TimeInterval?
    var animateDurationForBuildInByDefault: CGFloat { animateDurationForBuildIn ?? 0.5 }
    
    public var animateDurationForBuildOut: TimeInterval?
    var animateDurationForBuildOutByDefault: CGFloat { animateDurationForBuildOut ?? 0.38 }
    
    public var animateDurationForReload: TimeInterval?
    var animateDurationForReloadByDefault: CGFloat { animateDurationForReload ?? 0.8 }
    
    
    // MARK: 自定义
    
    /// 网络图标
    var customWebImage: ((_ imageView: UIImageView, _ imageURL: URL) -> Void)? = { imgv, url in
        DispatchQueue.global().async {
            URLSession.shared.dataTask(with: .init(url: url)) { data, resp, err in
                guard let data = data else {
                    return
                }
                DispatchQueue.main.async {
                    imgv.image = UIImage(data: data)
                }
            }.resume()
        }
    }
    public func customWebImage(handler: @escaping (_ imageView: UIImageView, _ imageURL: URL) -> Void) {
        customWebImage = handler
    }
    
    var customReloadData: ((_ vc: BaseController) -> Bool)?
    
    /// 自定义刷新规则（ ⚠️ 自定义此函数之后，整个容器将不再走默认布局规则，可实现完全自定义）
    /// - Parameter callback: 自定义刷新规则代码
    public func reloadData(_ callback: @escaping (_ vc: BaseController) -> Bool) {
        customReloadData = callback
    }
    
    /// 自定义内容卡片蒙版
    var customContentViewMask: ((_ mask: UIVisualEffectView) -> Void)?

    /// 设置内容卡片蒙版
    /// - Parameter callback: 自定义内容卡片蒙版代码
    public func contentViewMask(_ callback: @escaping (_ mask: UIVisualEffectView) -> Void) {
        customContentViewMask = callback
    }

    public override init() {
        
    }
    
}

