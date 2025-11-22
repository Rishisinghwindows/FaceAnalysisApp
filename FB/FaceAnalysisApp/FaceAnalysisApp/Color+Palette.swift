import SwiftUI

extension Color {
    static let primaryPink = Color(hex: 0xEE2B7C)
    static let backgroundLight = Color(hex: 0xF8F6F7)
    static let backgroundDark = Color(hex: 0x221018)
    static let textLight = Color(hex: 0x181114)
    static let textDark = Color(hex: 0xF8F6F7)
    static let subtleLight = Color(hex: 0x896172)
    static let subtleDark = Color(hex: 0xA18C95)
    static let borderLight = Color(hex: 0xE6DBE0)
    static let borderDark = Color(hex: 0x442E39)
    static let cardLight = Color(hex: 0xFFFFFF)
    static let cardDark = Color(hex: 0x2E1A23)
    static let secondaryButtonLight = Color(hex: 0xF4F0F2)
    static let secondaryButtonDark = Color(hex: 0x3A2531)
    static let resultPrimary = Color(hex: 0xE6C0C8)
    static let resultBackgroundLight = Color(hex: 0xF8F8F8)
    static let resultBackgroundDark = Color(hex: 0x21111C)
    static let resultTextLight = Color(hex: 0x333333)
    static let resultTextDark = Color(hex: 0xF8F6F7)
    static let resultTextSecondaryLight = Color(hex: 0x555555)
    static let resultTextSecondaryDark = Color(hex: 0xB89DAF)
    static let resultBorderLight = Color(hex: 0xD4B6A2)
    static let resultBorderDark = Color(hex: 0x382933)
    static let resultCardLight = Color(hex: 0xFFFFFF)
    static let resultCardDark = Color(hex: 0x2A1624)

    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex & 0xFF0000) >> 16) / 255,
            green: Double((hex & 0x00FF00) >> 8) / 255,
            blue: Double(hex & 0x0000FF) / 255,
            opacity: alpha
        )
    }
}
