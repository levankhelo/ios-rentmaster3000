import SwiftUI

struct ReportDetailsView: View {
    @Binding var draft: ReportDraft
    let onContinue: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case propertyName
        case reporter
        case recipient
        case description
        case requestedAction
    }

    var body: some View {
        Form {
            Section {
                Picker("Stay type", selection: $draft.stayType) {
                    ForEach(StayType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Context")
            }

            Section {
                TextField(draft.stayType.propertyPrompt, text: $draft.propertyName)
                    .textContentType(.fullStreetAddress)
                    .focused($focusedField, equals: .propertyName)
                    .accessibilityIdentifier("propertyField")

                DatePicker(
                    "When did you notice it?",
                    selection: $draft.incidentDate,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
            } header: {
                Text("Incident")
            } footer: {
                Text("Example: \(draft.stayType.propertyExample)")
            }

            Section {
                TextField("Your full name", text: $draft.reporterName)
                    .textContentType(.name)
                    .focused($focusedField, equals: .reporter)
                    .accessibilityIdentifier("reporterField")
                TextField("Recipient name (optional)", text: $draft.recipientName)
                    .textContentType(.name)
                    .focused($focusedField, equals: .recipient)
            } header: {
                Text("People")
            } footer: {
                Text("Use the landlord, property manager, or hotel manager’s name if you know it.")
            }

            Section {
                TextField(
                    "Describe the damage and where it is located",
                    text: $draft.damageDescription,
                    axis: .vertical
                )
                .lineLimit(5...10)
                .focused($focusedField, equals: .description)
                .accessibilityIdentifier("damageDescriptionField")

                TextField(
                    "Requested resolution (optional)",
                    text: $draft.requestedAction,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .focused($focusedField, equals: .requestedAction)
            } header: {
                Text("Details")
            } footer: {
                Text("Be specific and factual. You can edit the generated letter before exporting.")
            }
        }
        .navigationTitle("What happened?")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: draft.propertyName) { _, newValue in
            if newValue.count > 160 {
                draft.propertyName = String(newValue.prefix(160))
            }
        }
        .onChange(of: draft.reporterName) { _, newValue in
            if newValue.count > 100 {
                draft.reporterName = String(newValue.prefix(100))
            }
        }
        .onChange(of: draft.recipientName) { _, newValue in
            if newValue.count > 100 {
                draft.recipientName = String(newValue.prefix(100))
            }
        }
        .onChange(of: draft.damageDescription) { _, newValue in
            if newValue.count > 1_200 {
                draft.damageDescription = String(newValue.prefix(1_200))
            }
        }
        .onChange(of: draft.requestedAction) { _, newValue in
            if newValue.count > 500 {
                draft.requestedAction = String(newValue.prefix(500))
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                PrimaryActionButton(
                    "Add photo evidence",
                    systemImage: "arrow.right",
                    isDisabled: !draft.detailsAreComplete,
                    action: onContinue
                )
                if !draft.detailsAreComplete {
                    Text("Property, your name, and a damage description are required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }
}
