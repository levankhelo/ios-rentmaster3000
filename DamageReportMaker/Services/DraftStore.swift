import Foundation

final class DraftStore {
    static let shared = DraftStore()

    private let queue = DispatchQueue(
        label: "com.levankhelo.DamageReportMaker.draft-store",
        qos: .utility
    )
    private let fileURL: URL
    private var saveGeneration = 0

    private init(fileManager: FileManager = .default) {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let appDirectory = applicationSupport.appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "DamageReportMaker",
            isDirectory: true
        )
        fileURL = appDirectory.appendingPathComponent("unfinished-draft.plist")
    }

    func restore() -> ReportDraft? {
        queue.sync {
            guard
                let data = try? Data(contentsOf: fileURL),
                let draft = try? PropertyListDecoder().decode(ReportDraft.self, from: data),
                draft.hasMeaningfulContent
            else {
                return nil
            }
            return draft
        }
    }

    func scheduleSave(_ draft: ReportDraft) {
        queue.async {
            self.saveGeneration &+= 1
            let generation = self.saveGeneration
            self.queue.asyncAfter(deadline: .now() + .milliseconds(450)) {
                guard generation == self.saveGeneration else { return }
                Self.persist(draft, to: self.fileURL)
            }
        }
    }

    func flush(_ draft: ReportDraft) {
        queue.sync {
            saveGeneration &+= 1
            Self.persist(draft, to: fileURL)
        }
    }

    func clear() {
        queue.sync {
            saveGeneration &+= 1
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func persist(_ draft: ReportDraft, to fileURL: URL) {
        guard draft.hasMeaningfulContent else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary
            let data = try encoder.encode(draft)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("Unable to save unfinished report draft: \(error.localizedDescription)")
            #endif
        }
    }
}
