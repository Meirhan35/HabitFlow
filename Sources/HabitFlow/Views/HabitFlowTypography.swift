import SwiftUI

public enum HabitFlowTypography {
    public static func body(_ size: CGFloat = 14, weight: Font.Weight = .regular) -> Font {
        .custom("Inter", size: size).weight(weight)
    }

    public static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Cormorant Garamond", size: size).weight(weight)
    }

    public static func displayItalic(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom("Cormorant Garamond", size: size).weight(weight).italic()
    }

    public static func number(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        display(size, weight: weight).monospacedDigit()
    }
}
