import QuickLook
import Foundation
import SwiftUI
import UIKit

struct ReviewReportView: View {
    @Binding var draft: ReportDraft
    let onStartNewReport: () -> Void

    @AppStorage("demoAccessEnabled") private var demoAccessEnabled = false
    @State private var presentedSheet: ReviewSheet?
    @State private var generatedPDFURL: URL?
    @State private var generatedAt: Date?
    @State private var generatedPDFLetter: String?
    @State private var previewURL: URL?
    @State private var reviewAlert: ReviewAlert?
    @State private var isChoosingStaleLetterAction = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryCard
                evidenceCard
                letterCard
                timestampDisclosure

                if let generatedPDFURL, let generatedAt {
                    exportReadyCard(url: generatedPDFURL, generatedAt: generatedAt)
                }

                Button("Start a new report", systemImage: "arrow.counterclockwise") {
                    reviewAlert = .startNewReport
                }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .padding(.top, 4)
            }
            .padding(20)
            .padding(.bottom, 108)
        }
        .background(AppTheme.background)
        .navigationTitle("Review report")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: draft.complaintLetter) { _, newValue in
            if newValue.count > 3_000 {
                draft.complaintLetter = String(newValue.prefix(3_000))
            }
            if generatedPDFLetter != newValue {
                invalidateGeneratedPDF()
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .pricing:
                PricingView(onDemoEnabled: generatePDF)
            }
        }
        .alert(item: $reviewAlert) { alert in
            switch alert {
            case .exportError(let message):
                Alert(
                    title: Text("Couldn’t create the report"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            case .regenerateLetter:
                Alert(
                    title: Text("Regenerate complaint letter?"),
                    message: Text("This replaces your letter edits with a new version based on the current report details."),
                    primaryButton: .cancel(),
                    secondaryButton: .destructive(Text("Regenerate"), action: regenerateLetter)
                )
            case .startNewReport:
                Alert(
                    title: Text("Start a new report?"),
                    message: Text("The current details, photos, and letter will be removed from this draft."),
                    primaryButton: .cancel(),
                    secondaryButton: .destructive(Text("Start New")) {
                        invalidateGeneratedPDF()
                        onStartNewReport()
                    }
                )
            }
        }
        .confirmationDialog(
            "The complaint letter needs review",
            isPresented: $isChoosingStaleLetterAction,
            titleVisibility: .visible
        ) {
            Button("Regenerate and Continue") {
                regenerateLetter()
                continuePDFCreation()
            }
            Button("Keep My Edits and Continue") {
                draft.acknowledgeCurrentLetterForCurrentDetails()
                continuePDFCreation()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Report details changed after this letter was edited. Regenerate it or explicitly keep your current letter before exporting.")
        }
        .quickLookPreview($previewURL)
        .safeAreaInset(edge: .bottom) {
            bottomAction
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Incident details", systemImage: "list.clipboard.fill")
                .font(.title3.bold())
            SummaryRow(label: "Property / room", value: draft.propertyName.trimmed)
            SummaryRow(label: "Noticed", value: ReportFormatting.dateTime(draft.incidentDate))
            SummaryRow(label: "Prepared by", value: draft.reporterName.trimmed)
            SummaryRow(label: "Recipient", value: draft.recipientDisplayName)
            Divider()
            Text(draft.damageDescription.trimmed)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            if !draft.requestedAction.trimmed.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Requested resolution")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(draft.requestedAction.trimmed)
                        .font(.body)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reportCard()
    }

    private var evidenceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Photo evidence", systemImage: "photo.stack.fill")
                    .font(.title3.bold())
                Spacer()
                Text("\(draft.photos.count)")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.accentContent)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(draft.photos.enumerated()), id: \.element.id) { index, photo in
                        if let image = UIImage(data: photo.imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 112, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(alignment: .topLeading) {
                                    Text("\(index + 1)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(6)
                                        .background(.black.opacity(0.65), in: Circle())
                                        .padding(7)
                                }
                                .accessibilityLabel("Evidence photo \(index + 1)")
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reportCard()
    }

    private var letterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    complaintLetterHeading
                    Spacer()
                    regenerateButton
                }

                VStack(alignment: .leading, spacing: 8) {
                    complaintLetterHeading
                    regenerateButton
                }
            }

            Text("Edit anything before the letter is placed in the PDF.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if draft.letterNeedsRefresh {
                Label(
                    "Report details changed. Regenerate the letter or review and keep your edits before exporting.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("staleLetterWarning")
            }

            TextEditor(text: $draft.complaintLetter)
                .font(.body)
                .frame(minHeight: 280)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Editable complaint letter")

            HStack {
                Text("\(draft.complaintLetter.count) / 3,000")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                ShareLink(item: draft.complaintLetter) {
                    Label("Share letter", systemImage: "square.and.arrow.up")
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reportCard()
    }

    private func exportReadyCard(url: URL, generatedAt: Date) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("PDF ready", systemImage: "checkmark.seal.fill")
                .font(.title3.bold())
                .foregroundStyle(.green)
            Text("Generated \(ReportFormatting.dateTime(generatedAt))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Preview PDF", systemImage: "doc.text.magnifyingglass") {
                previewURL = url
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reportCard()
    }

    @ViewBuilder
    private var bottomAction: some View {
        if let generatedPDFURL {
            ShareLink(
                item: generatedPDFURL,
                subject: Text("Damage report for \(draft.propertyName.trimmed)"),
                message: Text("Attached is damage report \(draft.shortID).")
            ) {
                Label("Share PDF", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            PrimaryActionButton("Create PDF", systemImage: "doc.badge.clock", action: requestPDFCreation)
        }
    }

    private var complaintLetterHeading: some View {
        Label("Complaint letter", systemImage: "envelope.fill")
            .font(.title3.bold())
    }

    private var regenerateButton: some View {
        Button("Regenerate") {
            if draft.complaintLetterHasEdits {
                reviewAlert = .regenerateLetter
            } else {
                regenerateLetter()
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(AppTheme.accentContent)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityHint("Creates a new letter using the current report details")
    }

    private var timestampDisclosure: some View {
        Label(
            "The PDF records its creation time and when photos were added using this device's clock. It does not verify photo capture time.",
            systemImage: "clock.badge.questionmark"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .reportCard()
    }

    private func requestPDFCreation() {
        if draft.letterNeedsRefresh {
            isChoosingStaleLetterAction = true
        } else {
            continuePDFCreation()
        }
    }

    private func continuePDFCreation() {
        if demoAccessEnabled {
            generatePDF()
        } else {
            presentedSheet = .pricing
        }
    }

    private func regenerateLetter() {
        draft.replaceComplaintLetterWithGenerated(ComplaintLetterGenerator.generate(from: draft))
    }

    private func invalidateGeneratedPDF() {
        if let generatedPDFURL {
            try? FileManager.default.removeItem(at: generatedPDFURL)
        }
        previewURL = nil
        generatedPDFURL = nil
        generatedAt = nil
        generatedPDFLetter = nil
    }

    @MainActor
    private func generatePDF() {
        let timestamp = Date()
        do {
            generatedPDFURL = try PDFReportGenerator.generate(from: draft, generatedAt: timestamp)
            generatedAt = timestamp
            generatedPDFLetter = draft.complaintLetter
        } catch {
            reviewAlert = .exportError(error.localizedDescription)
        }
    }
}

private enum ReviewSheet: String, Identifiable {
    case pricing

    var id: String { rawValue }
}

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                summaryLabel
                    .frame(width: 100, alignment: .leading)
                summaryValue
            }

            VStack(alignment: .leading, spacing: 3) {
                summaryLabel
                summaryValue
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var summaryLabel: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var summaryValue: some View {
        Text(value)
            .font(.subheadline.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum ReviewAlert: Identifiable {
    case exportError(String)
    case regenerateLetter
    case startNewReport

    var id: String {
        switch self {
        case .exportError:
            "exportError"
        case .regenerateLetter:
            "regenerateLetter"
        case .startNewReport:
            "startNewReport"
        }
    }
}
