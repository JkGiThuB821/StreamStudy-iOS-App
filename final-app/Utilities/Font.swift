//
//  Font.swift
//  final-app
//
//  Created by Joy Jasmine Kaur on 1/10/2026.
//

import SwiftUI

extension Font {

    static func spaceGrotesk(
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> Font {

        switch weight {
        case .bold:
            return .custom("SpaceGrotesk-Bold", size: size)

        case .semibold:
            return .custom("SpaceGrotesk-SemiBold", size: size)

        case .medium:
            return .custom("SpaceGrotesk-Medium", size: size)

        default:
            return .custom("SpaceGrotesk-Regular", size: size)
        }
    }

    // Convenient semantic sizes
    static let sgLargeTitle = Font.spaceGrotesk(size: 34, weight: .bold)
    static let sgTitle = Font.spaceGrotesk(size: 28, weight: .bold)
    static let sgTitle2 = Font.spaceGrotesk(size: 22, weight: .semibold)
    static let sgTitle3 = Font.spaceGrotesk(size: 20, weight: .semibold)

    static let sgHeadline = Font.spaceGrotesk(size: 17, weight: .semibold)
    static let sgBody = Font.spaceGrotesk(size: 16)
    static let sgSubheadline = Font.spaceGrotesk(size: 15)
    static let sgCaption = Font.spaceGrotesk(size: 12)
    static let sgCaption2 = Font.spaceGrotesk(size: 11)
}
