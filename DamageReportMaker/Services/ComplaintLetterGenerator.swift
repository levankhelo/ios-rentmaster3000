import Foundation

enum ComplaintLetterGenerator {
    static func generate(from draft: ReportDraft) -> String {
        let property = draft.propertyName.trimmed
        let description = sentence(draft.damageDescription)
        let requestedAction = draft.requestedAction.trimmed.isEmpty
            ? "review this issue and tell me how it will be resolved"
            : draft.requestedAction.trimmed
        let evidenceText = draft.photos.count == 1
            ? "I have attached one photo showing the condition."
            : "I have attached \(draft.photos.count) photos showing the condition."

        return """
        Subject: Damage report - \(property)

        Dear \(draft.recipientDisplayName),

        I am writing to formally document damage I observed at \(property) on \(ReportFormatting.dateOnly(draft.incidentDate)). \(description) \(evidenceText)

        Requested resolution: \(sentence(requestedAction)) Please confirm receipt and let me know the next steps in writing.

        Sincerely,
        \(draft.reporterName.trimmed)
        """
    }

    private static func sentence(_ value: String) -> String {
        let text = value.trimmed
        guard let last = text.last, !".!?".contains(last) else { return text }
        return text + "."
    }
}
