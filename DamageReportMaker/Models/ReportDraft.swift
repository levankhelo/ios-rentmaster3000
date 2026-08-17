import Foundation

enum StayType: String, CaseIterable, Codable, Identifiable {
    case rental = "Rental"
    case hotel = "Hotel"

    var id: Self { self }

    var propertyPrompt: String {
        switch self {
        case .rental: "Property address"
        case .hotel: "Hotel and room"
        }
    }

    var propertyExample: String {
        switch self {
        case .rental: "42 Oak Street, Apartment 3B"
        case .hotel: "Sunrise Hotel, Room 407"
        }
    }

    var recipientFallback: String {
        switch self {
        case .rental: "Property Manager"
        case .hotel: "Hotel Manager"
        }
    }
}

struct EvidencePhoto: Codable, Equatable, Identifiable {
    let id: UUID
    let imageData: Data
    let addedAt: Date
    var caption: String

    init(id: UUID = UUID(), imageData: Data, addedAt: Date = Date(), caption: String = "") {
        self.id = id
        self.imageData = imageData
        self.addedAt = addedAt
        self.caption = caption
    }
}

struct ReportDraft: Codable, Equatable {
    var id = UUID()
    var stayType: StayType = .rental
    var propertyName = ""
    var incidentDate = Date()
    var reporterName = ""
    var recipientName = ""
    var damageDescription = ""
    var requestedAction = ""
    var photos: [EvidencePhoto] = []
    var complaintLetter = ""
    var lastGeneratedComplaintLetter = ""
    var letterSourceFingerprint = ""

    var shortID: String {
        String(id.uuidString.prefix(8)).uppercased()
    }

    var detailsAreComplete: Bool {
        !propertyName.trimmed.isEmpty
            && !reporterName.trimmed.isEmpty
            && !damageDescription.trimmed.isEmpty
    }

    var recipientDisplayName: String {
        recipientName.trimmed.isEmpty ? stayType.recipientFallback : recipientName.trimmed
    }

    var hasMeaningfulContent: Bool {
        !propertyName.trimmed.isEmpty
            || !reporterName.trimmed.isEmpty
            || !recipientName.trimmed.isEmpty
            || !damageDescription.trimmed.isEmpty
            || !requestedAction.trimmed.isEmpty
            || !photos.isEmpty
            || !complaintLetter.trimmed.isEmpty
    }

    var currentLetterSourceFingerprint: String {
        let sourceValues = [
            stayType.rawValue,
            propertyName.trimmed,
            String(incidentDate.timeIntervalSinceReferenceDate),
            reporterName.trimmed,
            recipientName.trimmed,
            damageDescription.trimmed,
            requestedAction.trimmed,
            String(photos.count)
        ]

        return sourceValues
            .map { "\($0.utf8.count):\($0)" }
            .joined(separator: "|")
    }

    var complaintLetterHasEdits: Bool {
        guard !complaintLetter.trimmed.isEmpty else { return false }
        guard !lastGeneratedComplaintLetter.isEmpty else { return true }
        return complaintLetter != lastGeneratedComplaintLetter
    }

    var letterNeedsRefresh: Bool {
        !complaintLetter.trimmed.isEmpty
            && !letterSourceFingerprint.isEmpty
            && letterSourceFingerprint != currentLetterSourceFingerprint
    }

    var shouldRefreshComplaintLetterAutomatically: Bool {
        complaintLetter.trimmed.isEmpty || !complaintLetterHasEdits
    }

    mutating func replaceComplaintLetterWithGenerated(_ letter: String) {
        complaintLetter = letter
        lastGeneratedComplaintLetter = letter
        letterSourceFingerprint = currentLetterSourceFingerprint
    }

    mutating func acknowledgeCurrentLetterForCurrentDetails() {
        letterSourceFingerprint = currentLetterSourceFingerprint
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
