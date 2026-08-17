import PhotosUI
import SwiftUI
import UIKit

struct EvidenceView: View {
    @Binding var draft: ReportDraft
    let onContinue: () -> Void

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    @State private var importNotice: ImportNotice?
    @State private var importTask: Task<Void, Never>?
    @State private var importSessionID: UUID?

    private let maximumPhotoCount = 8

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                intro

                if draft.photos.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(draft.photos.enumerated()), id: \.element.id) { index, photo in
                        EvidencePhotoCard(photo: $draft.photos[index], position: index + 1) {
                            let id = photo.id
                            withAnimation {
                                draft.photos.removeAll { $0.id == id }
                            }
                        }
                    }
                }

                if isImporting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Preparing photos…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }

                if draft.photos.count < maximumPhotoCount {
                    photoPicker
                }
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .accessibilityIdentifier("evidenceScreen")
        .background(AppTheme.background)
        .navigationTitle("Photo evidence")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            importTask?.cancel()
            let sessionID = UUID()
            let reportID = draft.id
            importSessionID = sessionID
            importTask = Task {
                await importPhotos(newItems, reportID: reportID, sessionID: sessionID)
            }
        }
        .onDisappear {
            importTask?.cancel()
            importTask = nil
            importSessionID = nil
            isImporting = false
            pickerItems = []
        }
        .alert(item: $importNotice) { notice in
            Alert(
                title: Text("Some photos weren’t added"),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                PrimaryActionButton(
                    "Review report",
                    systemImage: "arrow.right",
                    isDisabled: draft.photos.isEmpty || isImporting,
                    action: onContinue
                )
                if draft.photos.isEmpty {
                    Text("Add at least one photo to create a report.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Build a clear record", systemImage: "camera.fill")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text("Each image is labeled with the device time it was added to this report, not its original capture time. Add a short note so the damage is easy to identify.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .reportCard()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.accentContent)
            Text("No evidence added yet")
                .font(.headline)
            Text("Choose a wide shot and a close-up when possible.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .reportCard()
        .accessibilityElement(children: .combine)
    }

    private var photoPicker: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: maximumPhotoCount - draft.photos.count,
            selectionBehavior: .ordered,
            matching: .images
        ) {
            Label(
                draft.photos.isEmpty ? "Choose photos" : "Add more photos",
                systemImage: "photo.on.rectangle"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
        }
        .accessibilityIdentifier("photoPicker")
        .buttonStyle(.bordered)
        .disabled(isImporting)
        .accessibilityHint("Opens your photo library. You can add up to eight images.")
    }

    @MainActor
    private func importPhotos(
        _ items: [PhotosPickerItem],
        reportID: UUID,
        sessionID: UUID
    ) async {
        guard !isImporting else { return }
        isImporting = true
        var failedCount = 0
        let availableSlots = maximumPhotoCount - draft.photos.count

        defer {
            if importSessionID == sessionID {
                pickerItems = []
                isImporting = false
                importTask = nil
                importSessionID = nil
            }
        }

        for item in items.prefix(availableSlots) {
            guard !Task.isCancelled, draft.id == reportID else { return }

            do {
                guard let imported = try await item.loadTransferable(type: ImportedPhotoData.self) else {
                    failedCount += 1
                    continue
                }

                let jpeg = await ImageProcessor.normalizedJPEGOffMain(from: imported.data)
                guard !Task.isCancelled, draft.id == reportID else { return }
                guard let jpeg else {
                    failedCount += 1
                    continue
                }

                draft.photos.append(EvidencePhoto(imageData: jpeg))
            } catch {
                guard !Task.isCancelled, draft.id == reportID else { return }
                failedCount += 1
            }
        }

        if failedCount > 0, !Task.isCancelled, draft.id == reportID {
            importNotice = ImportNotice(
                message: "\(failedCount) photo\(failedCount == 1 ? "" : "s") could not be loaded. This can happen when an iCloud photo is temporarily unavailable."
            )
        }
    }
}

private struct EvidencePhotoCard: View {
    @Binding var photo: EvidencePhoto
    let position: Int
    let onDelete: () -> Void

    @State private var isConfirmingRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let image = UIImage(data: photo.imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel(photoAccessibilityLabel)
            }

            Label(
                "Added \(ReportFormatting.dateTime(photo.addedAt))",
                systemImage: "clock"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

            TextField("What does this photo show?", text: $photo.caption, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Description for evidence photo \(position)")
                .onChange(of: photo.caption) { _, newValue in
                    if newValue.count > 300 {
                        photo.caption = String(newValue.prefix(300))
                    }
                }

            Button("Remove photo", systemImage: "trash", role: .destructive) {
                isConfirmingRemoval = true
            }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Remove evidence photo \(position)")
        }
        .reportCard()
        .alert("Remove evidence photo \(position)?", isPresented: $isConfirmingRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive, action: onDelete)
        } message: {
            Text("This photo and its caption will be removed from the report.")
        }
    }

    private var photoAccessibilityLabel: String {
        let description = photo.caption.trimmed.isEmpty ? "No description" : photo.caption.trimmed
        return "Evidence photo \(position). \(description). Added \(ReportFormatting.dateTime(photo.addedAt))"
    }
}

private struct ImportNotice: Identifiable {
    let id = UUID()
    let message: String
}
