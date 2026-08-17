import CoreGraphics
import Foundation
import UIKit

enum PDFReportGeneratorError: LocalizedError {
    case invalidDocument

    var errorDescription: String? {
        "The report could not be rendered. Please try again."
    }
}

@MainActor
enum PDFReportGenerator {
    private static let navy = UIColor(red: 0.08, green: 0.13, blue: 0.22, alpha: 1)
    private static let accent = UIColor(red: 0.15, green: 0.37, blue: 0.69, alpha: 1)
    private static let muted = UIColor(red: 0.38, green: 0.42, blue: 0.49, alpha: 1)
    private static let paleBlue = UIColor(red: 0.94, green: 0.97, blue: 1, alpha: 1)
    private static let margin: CGFloat = 48

    private struct TextPreview {
        let text: String
        let fontSize: CGFloat
        let needsContinuation: Bool
    }

    private struct ContinuationPage {
        let title: String
        let sectionTitle: String
        let text: String
        let fontSize: CGFloat
        let part: Int
        let partCount: Int
    }

    private struct CoverLayout {
        let property: TextPreview
        let reporter: TextPreview
        let recipient: TextPreview
        let damage: TextPreview
        let requestedAction: TextPreview
        let continuationPages: [ContinuationPage]
    }

    private struct PaginatedText {
        let pages: [String]
        let fontSize: CGFloat
    }

    private struct EvidenceLayout {
        let caption: TextPreview
        let continuationPages: [ContinuationPage]
    }

    static func generate(from draft: ReportDraft, generatedAt: Date = Date()) throws -> URL {
        let bounds = paperBounds
        let coverLayout = makeCoverLayout(draft: draft, bounds: bounds)
        let letterLayout = makeLetterLayout(text: draft.complaintLetter, bounds: bounds)
        let evidenceLayouts = draft.photos.enumerated().map { index, photo in
            makeEvidenceLayout(photo: photo, index: index, bounds: bounds)
        }
        let pageCount = 1
            + coverLayout.continuationPages.count
            + letterLayout.pages.count
            + evidenceLayouts.reduce(0) { $0 + 1 + $1.continuationPages.count }

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Damage Report \(draft.shortID)",
            kCGPDFContextAuthor as String: draft.reporterName.trimmed,
            kCGPDFContextCreator as String: "Damage Report Maker",
            kCGPDFContextSubject as String: "Damage evidence for \(draft.propertyName.trimmed)"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)
        let data = renderer.pdfData { context in
            var page = 1

            context.beginPage()
            drawCover(
                draft: draft,
                layout: coverLayout,
                generatedAt: generatedAt,
                page: page,
                pageCount: pageCount,
                bounds: bounds
            )

            for continuation in coverLayout.continuationPages {
                page += 1
                context.beginPage()
                drawContinuation(
                    continuation,
                    draft: draft,
                    generatedAt: generatedAt,
                    page: page,
                    pageCount: pageCount,
                    bounds: bounds
                )
            }

            for (index, text) in letterLayout.pages.enumerated() {
                page += 1
                context.beginPage()
                drawLetter(
                    text: text,
                    fontSize: letterLayout.fontSize,
                    part: index + 1,
                    partCount: letterLayout.pages.count,
                    draft: draft,
                    generatedAt: generatedAt,
                    page: page,
                    pageCount: pageCount,
                    bounds: bounds
                )
            }

            for (index, photo) in draft.photos.enumerated() {
                let evidenceLayout = evidenceLayouts[index]
                page += 1
                context.beginPage()
                drawEvidence(
                    photo: photo,
                    index: index,
                    caption: evidenceLayout.caption,
                    draft: draft,
                    generatedAt: generatedAt,
                    page: page,
                    pageCount: pageCount,
                    bounds: bounds
                )

                for continuation in evidenceLayout.continuationPages {
                    page += 1
                    context.beginPage()
                    drawContinuation(
                        continuation,
                        draft: draft,
                        generatedAt: generatedAt,
                        page: page,
                        pageCount: pageCount,
                        bounds: bounds
                    )
                }
            }
        }

        guard !data.isEmpty else { throw PDFReportGeneratorError.invalidDocument }

        let directory = try exportsDirectory()
        let filename = "Damage-Report-\(draft.shortID)-\(ReportFormatting.filenameTimestamp(generatedAt)).pdf"
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        removeSupersededExports(in: directory, keeping: url)
        return url
    }

    private static var paperBounds: CGRect {
        let letterRegions = ["US", "CA", "MX"]
        let region = Locale.autoupdatingCurrent.region?.identifier ?? ""
        let size = letterRegions.contains(region)
            ? CGSize(width: 612, height: 792)
            : CGSize(width: 595.28, height: 841.89)
        return CGRect(origin: .zero, size: size)
    }

    private static func makeCoverLayout(draft: ReportDraft, bounds: CGRect) -> CoverLayout {
        let infoRect = CGRect(
            x: margin + 150,
            y: 0,
            width: bounds.width - margin * 2 - 168,
            height: 25
        )
        let damageRect = CGRect(x: margin, y: 382, width: bounds.width - margin * 2, height: 150)
        let requestedRect = CGRect(x: margin, y: 590, width: bounds.width - margin * 2, height: 70)
        let propertyText = draft.propertyName.trimmed
        let reporterText = draft.reporterName.trimmed
        let recipientText = draft.recipientDisplayName
        let requestedText = draft.requestedAction.trimmed.isEmpty
            ? "Please review this issue and advise how it will be resolved."
            : draft.requestedAction.trimmed

        let property = preview(
            propertyText,
            in: infoRect,
            maximumSize: 11,
            minimumSize: 7,
            weight: .semibold
        )
        let reporter = preview(
            reporterText,
            in: infoRect,
            maximumSize: 11,
            minimumSize: 7,
            weight: .semibold
        )
        let recipient = preview(
            recipientText,
            in: infoRect,
            maximumSize: 11,
            minimumSize: 7,
            weight: .semibold
        )
        let damage = preview(
            draft.damageDescription.trimmed,
            in: damageRect,
            maximumSize: 14,
            minimumSize: 10
        )
        let requestedAction = preview(
            requestedText,
            in: requestedRect,
            maximumSize: 13,
            minimumSize: 10
        )

        var continuations: [ContinuationPage] = []
        if property.needsContinuation {
            continuations += makeContinuationPages(
                title: "Report Details",
                sectionTitle: "Complete property / room",
                text: propertyText,
                bounds: bounds
            )
        }
        if reporter.needsContinuation {
            continuations += makeContinuationPages(
                title: "Report Details",
                sectionTitle: "Complete prepared by",
                text: reporterText,
                bounds: bounds
            )
        }
        if recipient.needsContinuation {
            continuations += makeContinuationPages(
                title: "Report Details",
                sectionTitle: "Complete recipient",
                text: recipientText,
                bounds: bounds
            )
        }
        if damage.needsContinuation {
            continuations += makeContinuationPages(
                title: "Report Details",
                sectionTitle: "Complete description",
                text: draft.damageDescription.trimmed,
                bounds: bounds
            )
        }
        if requestedAction.needsContinuation {
            continuations += makeContinuationPages(
                title: "Report Details",
                sectionTitle: "Complete requested resolution",
                text: requestedText,
                bounds: bounds
            )
        }

        return CoverLayout(
            property: property,
            reporter: reporter,
            recipient: recipient,
            damage: damage,
            requestedAction: requestedAction,
            continuationPages: continuations
        )
    }

    private static func makeLetterLayout(text: String, bounds: CGRect) -> PaginatedText {
        let rect = letterBodyRect(bounds: bounds)
        if let fontSize = fittedFontSize(
            text,
            in: rect,
            maximumSize: 13,
            minimumSize: 9
        ) {
            return PaginatedText(pages: [text], fontSize: fontSize)
        }

        let fontSize: CGFloat = 10
        return PaginatedText(
            pages: paginate(text, in: rect, font: .systemFont(ofSize: fontSize)),
            fontSize: fontSize
        )
    }

    private static func makeEvidenceLayout(
        photo: EvidencePhoto,
        index: Int,
        bounds: CGRect
    ) -> EvidenceLayout {
        let captionText = photo.caption.trimmed.isEmpty ? "No caption provided." : photo.caption.trimmed
        let captionRect = evidenceCaptionRect(bounds: bounds)
        let caption = preview(
            captionText,
            in: captionRect,
            maximumSize: 12,
            minimumSize: 9
        )
        let continuations = caption.needsContinuation
            ? makeContinuationPages(
                title: "Evidence \(index + 1) Note",
                sectionTitle: "Complete photo note",
                text: captionText,
                bounds: bounds
            )
            : []
        return EvidenceLayout(caption: caption, continuationPages: continuations)
    }

    private static func makeContinuationPages(
        title: String,
        sectionTitle: String,
        text: String,
        bounds: CGRect
    ) -> [ContinuationPage] {
        let fontSize: CGFloat = 12
        let pages = paginate(
            text,
            in: continuationBodyRect(bounds: bounds),
            font: .systemFont(ofSize: fontSize)
        )
        return pages.enumerated().map { index, text in
            ContinuationPage(
                title: title,
                sectionTitle: sectionTitle,
                text: text,
                fontSize: fontSize,
                part: index + 1,
                partCount: pages.count
            )
        }
    }

    private static func drawCover(
        draft: ReportDraft,
        layout: CoverLayout,
        generatedAt: Date,
        page: Int,
        pageCount: Int,
        bounds: CGRect
    ) {
        drawHeader(title: "Damage Report", subtitle: "REPORT \(draft.shortID)", bounds: bounds)

        let card = CGRect(x: margin, y: 132, width: bounds.width - margin * 2, height: 190)
        paleBlue.setFill()
        UIBezierPath(roundedRect: card, cornerRadius: 14).fill()

        drawInfoRow(label: "Property / room", value: layout.property, y: 148, bounds: bounds)
        drawInfoRow(
            label: "Report type",
            value: TextPreview(text: draft.stayType.rawValue, fontSize: 11, needsContinuation: false),
            y: 179,
            bounds: bounds
        )
        drawInfoRow(
            label: "Incident noticed",
            value: TextPreview(
                text: ReportFormatting.dateTime(draft.incidentDate),
                fontSize: 11,
                needsContinuation: false
            ),
            y: 210,
            bounds: bounds
        )
        drawInfoRow(label: "Prepared by", value: layout.reporter, y: 241, bounds: bounds)
        drawInfoRow(label: "Recipient", value: layout.recipient, y: 272, bounds: bounds)

        drawSectionTitle("What happened", y: 350, bounds: bounds)
        draw(
            layout.damage.text,
            in: CGRect(x: margin, y: 382, width: bounds.width - margin * 2, height: 150),
            font: .systemFont(ofSize: layout.damage.fontSize),
            color: navy
        )

        drawSectionTitle("Requested resolution", y: 558, bounds: bounds)
        draw(
            layout.requestedAction.text,
            in: CGRect(x: margin, y: 590, width: bounds.width - margin * 2, height: 70),
            font: .systemFont(ofSize: layout.requestedAction.fontSize),
            color: navy
        )

        draw(
            "Evidence attached: \(draft.photos.count) photo\(draft.photos.count == 1 ? "" : "s")",
            in: CGRect(x: margin, y: bounds.height - 94, width: bounds.width - margin * 2, height: 22),
            font: .systemFont(ofSize: 12, weight: .semibold),
            color: accent
        )
        drawFooter(generatedAt: generatedAt, page: page, pageCount: pageCount, bounds: bounds)
    }

    private static func drawContinuation(
        _ continuation: ContinuationPage,
        draft: ReportDraft,
        generatedAt: Date,
        page: Int,
        pageCount: Int,
        bounds: CGRect
    ) {
        let part = continuation.partCount == 1
            ? "CONTINUED"
            : "CONTINUED • PART \(continuation.part) OF \(continuation.partCount)"
        drawHeader(
            title: continuation.title,
            subtitle: "REPORT \(draft.shortID) • \(part)",
            bounds: bounds
        )
        drawSectionTitle(continuation.sectionTitle, y: 146, bounds: bounds)
        draw(
            continuation.text,
            in: continuationBodyRect(bounds: bounds),
            font: .systemFont(ofSize: continuation.fontSize),
            color: navy
        )
        drawFooter(generatedAt: generatedAt, page: page, pageCount: pageCount, bounds: bounds)
    }

    private static func drawLetter(
        text: String,
        fontSize: CGFloat,
        part: Int,
        partCount: Int,
        draft: ReportDraft,
        generatedAt: Date,
        page: Int,
        pageCount: Int,
        bounds: CGRect
    ) {
        let prefix = partCount == 1 ? "" : "PART \(part) OF \(partCount) • "
        drawHeader(
            title: "Complaint Letter",
            subtitle: "\(prefix)EDITED BY \(draft.reporterName.trimmed.uppercased())",
            bounds: bounds
        )
        draw(
            text,
            in: letterBodyRect(bounds: bounds),
            font: .systemFont(ofSize: fontSize),
            color: navy
        )
        drawFooter(generatedAt: generatedAt, page: page, pageCount: pageCount, bounds: bounds)
    }

    private static func drawEvidence(
        photo: EvidencePhoto,
        index: Int,
        caption: TextPreview,
        draft: ReportDraft,
        generatedAt: Date,
        page: Int,
        pageCount: Int,
        bounds: CGRect
    ) {
        drawHeader(title: "Evidence \(index + 1)", subtitle: "REPORT \(draft.shortID)", bounds: bounds)
        draw(
            "Added to report: \(ReportFormatting.dateTime(photo.addedAt))",
            in: CGRect(x: margin, y: 128, width: bounds.width - margin * 2, height: 20),
            font: .systemFont(ofSize: 11, weight: .medium),
            color: muted
        )

        let imageContainer = CGRect(
            x: margin,
            y: 160,
            width: bounds.width - margin * 2,
            height: bounds.height - 352
        )
        UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1).setFill()
        UIBezierPath(roundedRect: imageContainer, cornerRadius: 12).fill()

        if let image = UIImage(data: photo.imageData) {
            image.draw(in: aspectFitRect(for: image.size, inside: imageContainer.insetBy(dx: 10, dy: 10)))
        } else {
            draw(
                "Image unavailable",
                in: imageContainer,
                font: .systemFont(ofSize: 14, weight: .medium),
                color: muted,
                alignment: .center
            )
        }

        drawSectionTitle("Photo note", y: bounds.height - 166, bounds: bounds)
        draw(
            caption.text,
            in: evidenceCaptionRect(bounds: bounds),
            font: .systemFont(ofSize: caption.fontSize),
            color: navy
        )
        drawFooter(generatedAt: generatedAt, page: page, pageCount: pageCount, bounds: bounds)
    }

    private static func drawHeader(title: String, subtitle: String, bounds: CGRect) {
        draw(
            title,
            in: CGRect(x: margin, y: 48, width: bounds.width - margin * 2, height: 38),
            font: .systemFont(ofSize: 28, weight: .bold),
            color: navy
        )
        draw(
            subtitle,
            in: CGRect(x: margin, y: 88, width: bounds.width - margin * 2, height: 18),
            font: .systemFont(ofSize: 9, weight: .bold),
            color: accent
        )
        accent.setFill()
        UIBezierPath(roundedRect: CGRect(x: margin, y: 116, width: 48, height: 3), cornerRadius: 1.5).fill()
    }

    private static func drawInfoRow(label: String, value: TextPreview, y: CGFloat, bounds: CGRect) {
        draw(
            label.uppercased(),
            in: CGRect(x: margin + 18, y: y, width: 132, height: 18),
            font: .systemFont(ofSize: 8, weight: .bold),
            color: muted
        )
        draw(
            value.text,
            in: CGRect(x: margin + 150, y: y - 2, width: bounds.width - margin * 2 - 168, height: 25),
            font: .systemFont(ofSize: value.fontSize, weight: .semibold),
            color: navy
        )
    }

    private static func drawSectionTitle(_ title: String, y: CGFloat, bounds: CGRect) {
        draw(
            title,
            in: CGRect(x: margin, y: y, width: bounds.width - margin * 2, height: 24),
            font: .systemFont(ofSize: 16, weight: .bold),
            color: navy
        )
    }

    private static func drawFooter(generatedAt: Date, page: Int, pageCount: Int, bounds: CGRect) {
        draw(
            "Generated \(ReportFormatting.dateTime(generatedAt)) • \(ReportFormatting.timeZoneIdentifier) • Page \(page) of \(pageCount)",
            in: CGRect(x: margin, y: bounds.height - 62, width: bounds.width - margin * 2, height: 16),
            font: .systemFont(ofSize: 8, weight: .medium),
            color: muted
        )
        draw(
            "Creation and added-to-report times use the device clock and do not verify photo capture time. Author-supplied information; no independent damage verification or legal advice.",
            in: CGRect(x: margin, y: bounds.height - 46, width: bounds.width - margin * 2, height: 30),
            font: .systemFont(ofSize: 7),
            color: muted
        )
    }

    private static func letterBodyRect(bounds: CGRect) -> CGRect {
        CGRect(x: margin, y: 132, width: bounds.width - margin * 2, height: bounds.height - 220)
    }

    private static func evidenceCaptionRect(bounds: CGRect) -> CGRect {
        CGRect(x: margin, y: bounds.height - 138, width: bounds.width - margin * 2, height: 54)
    }

    private static func continuationBodyRect(bounds: CGRect) -> CGRect {
        CGRect(x: margin, y: 180, width: bounds.width - margin * 2, height: bounds.height - 260)
    }

    private static func preview(
        _ text: String,
        in rect: CGRect,
        maximumSize: CGFloat,
        minimumSize: CGFloat,
        weight: UIFont.Weight = .regular
    ) -> TextPreview {
        if let fontSize = fittedFontSize(
            text,
            in: rect,
            maximumSize: maximumSize,
            minimumSize: minimumSize,
            weight: weight
        ) {
            return TextPreview(text: text, fontSize: fontSize, needsContinuation: false)
        }

        let font = UIFont.systemFont(ofSize: minimumSize, weight: weight)
        let visible = splitText(text, in: rect, font: font).visible
        return TextPreview(
            text: ellipsized(visible, in: rect, font: font),
            fontSize: minimumSize,
            needsContinuation: true
        )
    }

    private static func fittedFontSize(
        _ text: String,
        in rect: CGRect,
        maximumSize: CGFloat,
        minimumSize: CGFloat,
        weight: UIFont.Weight = .regular
    ) -> CGFloat? {
        var size = maximumSize
        while size >= minimumSize {
            let font = UIFont.systemFont(ofSize: size, weight: weight)
            if measuredHeight(text, width: rect.width, font: font) <= rect.height - 1 {
                return size
            }
            size -= 0.5
        }
        return nil
    }

    private static func paginate(_ text: String, in rect: CGRect, font: UIFont) -> [String] {
        guard !text.isEmpty else { return [""] }

        var pages: [String] = []
        var remainder = text
        while !remainder.isEmpty {
            let split = splitText(remainder, in: rect, font: font)
            guard !split.visible.isEmpty else {
                let nextIndex = remainder.index(after: remainder.startIndex)
                pages.append(String(remainder[..<nextIndex]))
                remainder = String(remainder[nextIndex...])
                continue
            }
            pages.append(split.visible)
            remainder = split.remainder
        }
        return pages
    }

    private static func splitText(
        _ text: String,
        in rect: CGRect,
        font: UIFont
    ) -> (visible: String, remainder: String) {
        guard measuredHeight(text, width: rect.width, font: font) > rect.height - 1 else {
            return (text, "")
        }

        let characters = Array(text)
        var lowerBound = 1
        var upperBound = characters.count
        var bestCount = 0

        while lowerBound <= upperBound {
            let candidateCount = (lowerBound + upperBound) / 2
            let candidate = String(characters.prefix(candidateCount))
            if measuredHeight(candidate, width: rect.width, font: font) <= rect.height - 1 {
                bestCount = candidateCount
                lowerBound = candidateCount + 1
            } else {
                upperBound = candidateCount - 1
            }
        }

        guard bestCount > 0 else { return ("", text) }
        return (
            String(characters.prefix(bestCount)),
            String(characters.dropFirst(bestCount))
        )
    }

    private static func ellipsized(_ text: String, in rect: CGRect, font: UIFont) -> String {
        var characters = Array(text.trimmingCharacters(in: .whitespacesAndNewlines))
        while !characters.isEmpty {
            let candidate = String(characters) + "…"
            if measuredHeight(candidate, width: rect.width, font: font) <= rect.height - 1 {
                return candidate
            }
            characters.removeLast()
        }
        return "…"
    }

    private static func measuredHeight(_ text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        return ceil((text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil
        ).height)
    }

    private static func draw(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.alignment = alignment
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph],
            context: nil
        )
    }

    private static func exportsDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DamageReportMaker", isDirectory: true)
            .appendingPathComponent("Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func removeSupersededExports(in directory: URL, keeping currentURL: URL) {
        let fileManager = FileManager.default
        let current = currentURL.standardizedFileURL
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for url in urls where url.standardizedFileURL != current {
            guard url.pathExtension.lowercased() == "pdf",
                  url.lastPathComponent.hasPrefix("Damage-Report-"),
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else {
                continue
            }
            try? fileManager.removeItem(at: url)
        }
    }

    private static func aspectFitRect(for imageSize: CGSize, inside rect: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return rect }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
