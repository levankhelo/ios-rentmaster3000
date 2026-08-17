import XCTest

final class DamageReportMakerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testDetailsFormEnablesEvidenceStep() {
        let app = launchApp(additionalArguments: ["-ui-testing-details"])

        let propertyField = app.descendants(matching: .any).matching(identifier: "propertyField").firstMatch
        XCTAssertTrue(propertyField.waitForExistence(timeout: 2))
        let reporterField = app.descendants(matching: .any).matching(identifier: "reporterField").firstMatch
        let descriptionField = app.descendants(matching: .any).matching(identifier: "damageDescriptionField").firstMatch
        XCTAssertEqual(propertyField.value as? String, "42 Oak Street")
        XCTAssertEqual(reporterField.value as? String, "Alex Morgan")
        XCTAssertEqual(descriptionField.value as? String, "Water is leaking above the bedroom window.")

        let continueButton = app.buttons["Add photo evidence"]
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        let evidenceScreen = app.descendants(matching: .any).matching(identifier: "evidenceScreen").firstMatch
        XCTAssertTrue(evidenceScreen.waitForExistence(timeout: 5))
    }

    func testPricingExplainsPrototypeAndExactPlans() {
        let app = launchApp()

        app.buttons["Plans"].tap()

        XCTAssertTrue(app.staticTexts["$9.99 once"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["$4.99/month"].exists)
        XCTAssertTrue(app.staticTexts["Purchases aren’t available in this build"].exists)
        XCTAssertTrue(app.buttons["Continue with demo access"].exists)
    }

    func testSeededReportGeneratesPDFThroughDemoAccess() {
        let app = launchApp(additionalArguments: ["-ui-testing-review"])

        XCTAssertTrue(app.staticTexts["Review report"].waitForExistence(timeout: 3))
        app.buttons["Create PDF"].tap()

        let demoButton = app.buttons["Continue with demo access"]
        if demoButton.waitForExistence(timeout: 2) {
            demoButton.tap()
        }

        XCTAssertTrue(app.buttons["Share PDF"].waitForExistence(timeout: 4))
    }

    private func launchApp(additionalArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing-reset-demo"] + additionalArguments
        app.launch()
        return app
    }
}
