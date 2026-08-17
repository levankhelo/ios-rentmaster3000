import SwiftUI

struct PricingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("demoAccessEnabled") private var demoAccessEnabled = false

    private let onDemoEnabled: (() -> Void)?

    init(onDemoEnabled: (() -> Void)? = nil) {
        self.onDemoEnabled = onDemoEnabled
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header

                    PricingPlanCard(
                        title: "One-time",
                        price: "$9.99 once",
                        detail: "One payment to unlock report export.",
                        badge: "Best value"
                    )

                    PricingPlanCard(
                        title: "Monthly",
                        price: "$4.99/month",
                        detail: "Recurring access to report export. Cancel anytime.",
                        badge: nil
                    )

                    prototypeNotice

                    if demoAccessEnabled {
                        Label("Demo access is enabled", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))

                        PrimaryActionButton("Done", systemImage: "checkmark") {
                            dismiss()
                        }
                    } else {
                        PrimaryActionButton("Continue with demo access", systemImage: "arrow.right") {
                            demoAccessEnabled = true
                            onDemoEnabled?()
                            dismiss()
                        }
                    }

                    Text("Before release, these planned prices will be loaded from App Store products. No purchase is made in this build.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle("Unlock reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(AppTheme.accentContent)
                .frame(minWidth: 76, minHeight: 76)
                .background(AppTheme.softAccent, in: RoundedRectangle(cornerRadius: 22))
                .accessibilityHidden(true)

            Text("Create a report you can send today.")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("Export PDFs that record when the report was generated and when each photo was added, plus editable complaint letters.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private var prototypeNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Purchases aren’t available in this build", systemImage: "hammer.fill")
                .font(.headline)
            Text("App Store products have not been configured. Demo access lets you test PDF export and sharing without a charge.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PricingPlanCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let price: String
    let detail: String
    let badge: String?

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    planIcon
                    planDetails
                }
            } else {
                HStack(alignment: .top, spacing: 14) {
                    planIcon
                    planDetails
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reportCard()
        .accessibilityElement(children: .combine)
    }

    private var planIcon: some View {
        Image(systemName: title == "One-time" ? "checkmark.seal" : "calendar")
            .font(.title2.weight(.semibold))
            .foregroundStyle(AppTheme.accentContent)
            .frame(minWidth: 44, minHeight: 44)
            .background(AppTheme.softAccent, in: Circle())
            .accessibilityHidden(true)
    }

    private var planDetails: some View {
        VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    planTitle
                    planBadge
                }

                VStack(alignment: .leading, spacing: 6) {
                    planTitle
                    planBadge
                }
            }

            Text(price)
                .font(.title3.bold())
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Planned price")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var planTitle: some View {
        Text(title)
            .font(.headline)
    }

    @ViewBuilder
    private var planBadge: some View {
        if let badge {
            Text(badge)
                .font(.caption2.bold())
                .foregroundStyle(AppTheme.accentContent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.softAccent, in: Capsule())
                .fixedSize(horizontal: true, vertical: true)
        }
    }
}
