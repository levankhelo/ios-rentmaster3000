import CoreTransferable
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

struct ImportedPhotoData: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            ImportedPhotoData(data: data)
        }
    }
}

enum ImageProcessor {
    static func normalizedJPEGOffMain(from data: Data, maxPixelSize: CGFloat = 2_400) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            normalizedJPEG(from: data, maxPixelSize: maxPixelSize)
        }.value
    }

    static func normalizedJPEG(from data: Data, maxPixelSize: CGFloat = 2_400) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: image).jpegData(compressionQuality: 0.84)
    }
}
