# Damage Report Maker

A small, local-first SwiftUI prototype for renters and hotel guests who need to document property damage quickly.

## First-draft features

- Rental and hotel report flows
- Incident details and requested-resolution fields
- Up to eight photo-evidence attachments with honest “added to report” timestamps
- On-device autosave and restore for unfinished drafts
- Deterministic, editable complaint-letter generation with no network or AI dependency
- Letter/A4 PDF export marked with its device-clock creation time and each photo's added-to-report time
- Native PDF preview and share sheet
- Planned pricing UI for a $9.99 one-time unlock or $4.99/month subscription
- Transparent demo access while StoreKit products are not configured

The prototype processes entered details and photos on-device. It does not upload report content.

## Requirements

- Xcode 16 or newer
- iOS 17 or newer
- XcodeGen 2.45+ only when regenerating the project

## Run

Open `DamageReportMaker.xcodeproj`, select the `DamageReportMaker` scheme, and run on an iPhone Simulator.

To regenerate the Xcode project:

```sh
xcodegen generate --spec project.yml
```

Run tests from Xcode or with the command below. The simulator name is an
example; replace it with any installed device listed by
`xcrun simctl list devices available`.

```sh
xcodebuild \
  -project DamageReportMaker.xcodeproj \
  -scheme DamageReportMaker \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

## Prototype note

The plan prices are placeholders until matching App Store Connect products and StoreKit 2 entitlements are added. Purchase-looking controls are intentionally disabled; demo access keeps PDF creation testable without charging anyone.
