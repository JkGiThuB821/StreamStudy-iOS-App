//
//  Font.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 1/10/2026.
//

import SwiftUI
import UIKit

extension Font {

    // Every Space Grotesk font scales with Dynamic Type. If no text style is given,
    // one is picked from the point size so e.g. a 28pt title grows like .title.
    static func spaceGrotesk(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: Font.TextStyle? = nil
    ) -> Font {
        .custom(spaceGroteskName(for: weight), size: size, relativeTo: style ?? textStyle(for: size))
    }

    static func spaceGroteskName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black:
            return "SpaceGrotesk-Bold"
        case .semibold:
            return "SpaceGrotesk-SemiBold"
        case .medium:
            return "SpaceGrotesk-Medium"
        default:
            return "SpaceGrotesk-Regular"
        }
    }

    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 34...: return .largeTitle
        case 28..<34: return .title
        case 22..<28: return .title2
        case 20..<22: return .title3
        case 17..<20: return .body
        case 16..<17: return .callout
        case 15..<16: return .subheadline
        case 13..<15: return .footnote
        case 12..<13: return .caption
        default: return .caption2
        }
    }

    // Convenient semantic sizes
    static let sgLargeTitle = Font.spaceGrotesk(size: 34, weight: .bold)
    static let sgTitle = Font.spaceGrotesk(size: 28, weight: .bold)
    static let sgTitle2 = Font.spaceGrotesk(size: 22, weight: .semibold)
    static let sgTitle3 = Font.spaceGrotesk(size: 20, weight: .semibold)

    static let sgHeadline = Font.spaceGrotesk(size: 17, weight: .semibold, relativeTo: .headline)
    static let sgBody = Font.spaceGrotesk(size: 16, relativeTo: .body)
    static let sgSubheadline = Font.spaceGrotesk(size: 15)
    static let sgCaption = Font.spaceGrotesk(size: 12)
    static let sgCaption2 = Font.spaceGrotesk(size: 11)
}

extension UIFont {

    // UIKit version for places SwiftUI fonts can't reach (navigation bar titles).
    // Scaled with UIFontMetrics so it follows Dynamic Type too.
    static func spaceGrotesk(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo style: UIFont.TextStyle
    ) -> UIFont {
        let base = UIFont(name: Font.spaceGroteskName(for: weight), size: size)
            ?? .preferredFont(forTextStyle: style)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}
