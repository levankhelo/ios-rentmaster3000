import PDFKit
import UIKit
import XCTest
@testable import DamageReportMaker

@MainActor
final class DamageReportMakerTests: XCTestCase {
    func testRequiredDetailsValidation() {
        var draft = ReportDraft()
        XCTAssertFalse(draft.detailsAreComplete)

        draft.propertyName = "  Sunrise Hotel, Room 407  "
        draft.reporterName = "Alex Morgan"
        draft.damageDescription = "Water is leaking above the bed."

        XCTAssertTrue(draft.detailsAreComplete)
    }

    func testComplaintLetterUsesFallbackRecipientAndRequestedAction() {
        var draft = completeDraft
        draft.stayType = .hotel
        draft.recipientName = ""
        draft.requestedAction = ""
        draft.photos = [EvidencePhoto(imageData: Data())]

        let letter = ComplaintLetterGenerator.generate(from: draft)

        XCTAssertTrue(letter.contains("Dear Hotel Manager,"))
        XCTAssertTrue(letter.contains("one photo showing the condition"))
        XCTAssertTrue(letter.contains("review this issue and tell me how it will be resolved"))
        XCTAssertTrue(letter.contains("Sincerely,\nAlex Morgan"))
    }

    func testComplaintLetterPluralizesEvidenceCount() {
        var draft = completeDraft
        draft.photos = [
            EvidencePhoto(imageData: Data()),
            EvidencePhoto(imageData: Data())
        ]

        let letter = ComplaintLetterGenerator.generate(from: draft)

        XCTAssertTrue(letter.contains("2 photos showing the condition"))
    }

    func testComplaintLetterPreservesRequestedResolutionCasing() {
        var draft = completeDraft
        draft.requestedAction = "HVAC Team ABC should inspect the unit"

        let letter = ComplaintLetterGenerator.generate(from: draft)

        XCTAssertTrue(letter.contains("Requested resolution: HVAC Team ABC should inspect the unit."))
        XCTAssertFalse(letter.contains("hVAC Team ABC"))
    }

    func testGeneratedLetterBecomesStaleAndCanBeExplicitlyAccepted() {
        var draft = completeDraft
        draft.photos = [EvidencePhoto(imageData: sampleJPEG)]
        draft.replaceComplaintLetterWithGenerated(ComplaintLetterGenerator.generate(from: draft))

        XCTAssertFalse(draft.complaintLetterHasEdits)
        XCTAssertFalse(draft.letterNeedsRefresh)

        draft.complaintLetter += "\n\nPlease contact me by email."
        draft.propertyName = "Sunrise Hotel, Room 512"

        XCTAssertTrue(draft.complaintLetterHasEdits)
        XCTAssertTrue(draft.letterNeedsRefresh)
        XCTAssertFalse(draft.shouldRefreshComplaintLetterAutomatically)

        draft.acknowledgeCurrentLetterForCurrentDetails()

        XCTAssertFalse(draft.letterNeedsRefresh)
        XCTAssertTrue(draft.complaintLetterHasEdits)
    }

    func testUneditedGeneratedLetterCanRefreshAfterDetailsChange() {
        var draft = completeDraft
        draft.photos = [EvidencePhoto(imageData: sampleJPEG)]
        draft.replaceComplaintLetterWithGenerated(ComplaintLetterGenerator.generate(from: draft))

        draft.damageDescription = "A new factual description."

        XCTAssertTrue(draft.letterNeedsRefresh)
        XCTAssertTrue(draft.shouldRefreshComplaintLetterAutomatically)
    }

    func testGeneratedPDFHasCoverLetterAndEvidencePage() throws {
        var draft = completeDraft
        draft.photos = [EvidencePhoto(imageData: sampleJPEG, caption: "Ceiling stain above the bed")]
        draft.complaintLetter = ComplaintLetterGenerator.generate(from: draft)

        let url = try PDFReportGenerator.generate(
            from: draft,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let document = PDFDocument(url: url)
        XCTAssertEqual(document?.pageCount, 3)
        XCTAssertGreaterThan((try Data(contentsOf: url)).count, 1_000)
        XCTAssertEqual(url.pathExtension, "pdf")
    }

    func testGeneratedPDFPreservesMaximumLengthInputTails() throws {
        let propertyTail = "ZZPROPERTYTAIL9173"
        let reporterTail = "ZZREPORTERTAIL4826"
        let recipientTail = "ZZRECIPIENTTAIL3051"
        let damageTail = "ZZDAMAGETAIL7684"
        let requestedTail = "ZZREQUESTTAIL1592"
        let letterTail = "ZZLETTERTAIL6408"
        let captionTail = "ZZCAPTIONTAIL2735"

        var draft = completeDraft
        draft.propertyName = maximumText(length: 160, tail: propertyTail, lineBreaks: false)
        draft.reporterName = maximumText(length: 100, tail: reporterTail, lineBreaks: false)
        draft.recipientName = maximumText(length: 100, tail: recipientTail, lineBreaks: false)
        draft.damageDescription = maximumText(length: 1_200, tail: damageTail, lineBreaks: true)
        draft.requestedAction = maximumText(length: 500, tail: requestedTail, lineBreaks: true)
        draft.complaintLetter = maximumText(length: 3_000, tail: letterTail, lineBreaks: true)
        draft.photos = [
            EvidencePhoto(
                imageData: sampleJPEG,
                caption: maximumText(length: 300, tail: captionTail, lineBreaks: true)
            )
        ]

        let url = try PDFReportGenerator.generate(
            from: draft,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try XCTUnwrap(PDFDocument(url: url))
        let extractedText = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")

        XCTAssertGreaterThan(document.pageCount, 3)
        for tail in [
            propertyTail,
            reporterTail,
            recipientTail,
            damageTail,
            requestedTail,
            letterTail,
            captionTail
        ] {
            XCTAssertTrue(extractedText.contains(tail), "Missing PDF tail sentinel: \(tail)")
        }
        for index in 0..<document.pageCount {
            XCTAssertTrue(
                document.page(at: index)?.string?.contains("Page \(index + 1) of \(document.pageCount)") == true,
                "Missing or incorrect page number on page \(index + 1)"
            )
        }
    }

    func testGeneratingNewPDFRemovesOnlySupersededAppExports() throws {
        let firstURL = try PDFReportGenerator.generate(
            from: completeDraft,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))
        let unrelatedURL = firstURL.deletingLastPathComponent().appendingPathComponent("keep-this-file.txt")
        try Data("unrelated".utf8).write(to: unrelatedURL)
        defer { try? FileManager.default.removeItem(at: unrelatedURL) }

        let secondURL = try PDFReportGenerator.generate(
            from: completeDraft,
            generatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        defer { try? FileManager.default.removeItem(at: secondURL) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelatedURL.path))
        XCTAssertEqual(secondURL.deletingLastPathComponent().lastPathComponent, "Exports")
        XCTAssertEqual(secondURL.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent, "DamageReportMaker")
    }

    private var completeDraft: ReportDraft {
        var draft = ReportDraft()
        draft.propertyName = "Sunrise Hotel, Room 407"
        draft.reporterName = "Alex Morgan"
        draft.recipientName = "Jordan Lee"
        draft.damageDescription = "Water was leaking from the ceiling above the bed."
        draft.requestedAction = "repair the leak and confirm the room is safe"
        draft.incidentDate = Date(timeIntervalSince1970: 1_700_000_000)
        return draft
    }

    private var sampleJPEG: Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 240))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 320, height: 240))
            UIColor.white.setFill()
            context.fill(CGRect(x: 70, y: 70, width: 180, height: 100))
        }
        return image.jpegData(compressionQuality: 0.85)!
    }

    private func maximumText(length: Int, tail: String, lineBreaks: Bool) -> String {
        let separator = lineBreaks ? "Evidence detail line.\n" : " WIDEFIELD "
        let suffix = (lineBreaks ? "\n" : " ") + tail
        precondition(suffix.count <= length)

        var text = ""
        while text.count + separator.count + suffix.count <= length {
            text += separator
        }
        text += String(repeating: lineBreaks ? "x" : "W", count: length - text.count - suffix.count)
        text += suffix
        precondition(text.count == length)
        return text
    }
}
