import SwiftUI
import UIKit

private enum ReportRoute: Hashable {
    case details
    case evidence
    case review
}

private enum AppSheet: String, Identifiable {
    case pricing

    var id: String { rawValue }
}

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = ReportDraft()
    @State private var path: [ReportRoute] = []
    @State private var presentedSheet: AppSheet?
    private let persistenceEnabled: Bool

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        #if DEBUG
        let isRunningUITests = arguments.contains { $0.hasPrefix("-ui-testing-") }
        persistenceEnabled = !isRunningUITests

        if isRunningUITests {
            DraftStore.shared.clear()
        }
        if arguments.contains("-ui-testing-reset-demo") {
            UserDefaults.standard.removeObject(forKey: "demoAccessEnabled")
        }
        if arguments.contains("-ui-testing-review") {
            _draft = State(initialValue: .uiTestSample)
            _path = State(initialValue: [.details, .evidence, .review])
        } else if arguments.contains("-ui-testing-details") {
            _draft = State(initialValue: .uiTestDetailsSample)
            _path = State(initialValue: [.details])
        } else if let savedDraft = DraftStore.shared.restore() {
            _draft = State(initialValue: savedDraft)
            _path = State(initialValue: [.details])
        }
        #else
        persistenceEnabled = true
        if let savedDraft = DraftStore.shared.restore() {
            _draft = State(initialValue: savedDraft)
            _path = State(initialValue: [.details])
        }
        #endif
    }

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                hasDraft: draft.hasMeaningfulContent,
                onStart: startReport,
                onShowPlans: { presentedSheet = .pricing }
            )
            .navigationDestination(for: ReportRoute.self) { route in
                switch route {
                case .details:
                    ReportDetailsView(draft: $draft) {
                        path.append(.evidence)
                    }
                case .evidence:
                    EvidenceView(draft: $draft) {
                        if draft.shouldRefreshComplaintLetterAutomatically {
                            let letter = ComplaintLetterGenerator.generate(from: draft)
                            draft.replaceComplaintLetterWithGenerated(letter)
                        }
                        path.append(.review)
                    }
                case .review:
                    ReviewReportView(draft: $draft) {
                        clearSavedDraft()
                        draft = ReportDraft()
                        path.removeAll()
                    }
                }
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .pricing:
                PricingView()
            }
        }
        .onChange(of: draft) { _, updatedDraft in
            guard persistenceEnabled else { return }
            DraftStore.shared.scheduleSave(updatedDraft)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard persistenceEnabled, newPhase != .active else { return }
            DraftStore.shared.flush(draft)
        }
    }

    private func startReport() {
        if !draft.hasMeaningfulContent {
            clearSavedDraft()
            draft = ReportDraft()
        }
        path = [.details]
    }

    private func clearSavedDraft() {
        guard persistenceEnabled else { return }
        DraftStore.shared.clear()
    }
}

#if DEBUG
private extension ReportDraft {
    static var uiTestDetailsSample: ReportDraft {
        var draft = ReportDraft()
        draft.propertyName = "42 Oak Street"
        draft.reporterName = "Alex Morgan"
        draft.damageDescription = "Water is leaking above the bedroom window."
        return draft
    }

    static var uiTestSample: ReportDraft {
        var draft = ReportDraft()
        draft.stayType = .hotel
        draft.propertyName = "Sunrise Hotel, Room 407"
        draft.incidentDate = Date(timeIntervalSince1970: 1_700_000_000)
        draft.reporterName = "Alex Morgan"
        draft.recipientName = "Hotel Manager"
        draft.damageDescription = "Water was leaking from the ceiling above the bed."
        draft.requestedAction = "repair the leak and confirm the room is safe"
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 480))
        let image = renderer.image { context in
            UIColor(red: 0.86, green: 0.84, blue: 0.78, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
            UIColor(red: 0.47, green: 0.33, blue: 0.20, alpha: 0.78).setFill()
            UIBezierPath(ovalIn: CGRect(x: 170, y: 90, width: 300, height: 210)).fill()
            UIColor(red: 0.25, green: 0.20, blue: 0.16, alpha: 0.68).setStroke()
            let crack = UIBezierPath()
            crack.move(to: CGPoint(x: 320, y: 230))
            crack.addLine(to: CGPoint(x: 370, y: 315))
            crack.addLine(to: CGPoint(x: 350, y: 385))
            crack.lineWidth = 8
            crack.stroke()
        }
        let imageData = image.jpegData(compressionQuality: 0.85) ?? Data()
        draft.photos = [
            EvidencePhoto(
                imageData: imageData,
                addedAt: Date(timeIntervalSince1970: 1_700_000_100),
                caption: "Ceiling stain above the bed"
            )
        ]
        let letter = ComplaintLetterGenerator.generate(from: draft)
        draft.replaceComplaintLetterWithGenerated(letter)
        return draft
    }
}
#endif

#Preview {
    AppRootView()
}
