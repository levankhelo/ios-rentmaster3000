import SwiftUI

struct HomeView: View {
    let hasDraft: Bool
    let onStart: () -> Void
    let onShowPlans: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                workflow
                pricingSummary
                privacyNote
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .background(AppTheme.background)
        .navigationTitle("Damage Reports")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Plans", systemImage: "sparkles", action: onShowPlans)
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryActionButton(
                hasDraft ? "Resume damage report" : "Start damage report",
                systemImage: hasDraft ? "arrow.right" : "plus",
                action: onStart
            )
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppTheme.softAccent)
                    .frame(width: 64, height: 64)
                Image(systemName: "shield.checkered")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(AppTheme.accentContent)
                    .accessibilityHidden(true)
            }

            Text("Document it while it’s fresh.")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)

            Text("Add photos and details, then create a PDF that records when it was generated and when each photo was added, plus an editable complaint letter.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reportCard()
    }

    private var workflow: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Three quick steps")
                .font(.title2.bold())
            FlowStepRow(
                number: 1,
                title: "Describe the damage",
                detail: "Record where and when you noticed it.",
                systemImage: "square.and.pencil"
            )
            Divider()
            FlowStepRow(
                number: 2,
                title: "Add evidence",
                detail: "Choose up to eight photos. The report records when each was added.",
                systemImage: "photo.on.rectangle.angled"
            )
            Divider()
            FlowStepRow(
                number: 3,
                title: "Export and send",
                detail: "Review your letter, create the PDF, and share it.",
                systemImage: "doc.richtext"
            )
        }
        .reportCard()
    }

    private var pricingSummary: some View {
        Button(action: onShowPlans) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accentContent)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.softAccent, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Simple planned pricing")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("$9.99 once or $4.99/month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .reportCard()
        .accessibilityHint("Shows plan details")
    }

    private var privacyNote: some View {
        Label(
            "Your details and photos are processed on this iPhone. Nothing is uploaded by this prototype.",
            systemImage: "lock.fill"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }
}
