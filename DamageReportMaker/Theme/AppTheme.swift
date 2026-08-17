import SwiftUI

enum AppTheme {
    static let accent = Color.accentColor
    static let accentContent = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.40, green: 0.66, blue: 1.00, alpha: 1.00)
            }

            return UIColor(red: 0.15, green: 0.37, blue: 0.69, alpha: 1.00)
        }
    )
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let raisedCard = Color(uiColor: .systemBackground)
    static let softAccent = Color.accentColor.opacity(0.12)
    static let warning = Color.orange
    static let cornerRadius: CGFloat = 18
}

private struct ReportCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(AppTheme.raisedCard, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            }
    }
}

extension View {
    func reportCard() -> some View {
        modifier(ReportCardModifier())
    }
}
