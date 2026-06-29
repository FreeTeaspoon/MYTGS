import XCTest

@MainActor
final class MYTGSMacUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        if app.state != .notRunning {
            app.terminate()
            _ = app.wait(for: .notRunning, timeout: 5)
        }
        app = nil
    }

    func testSidebarAndSignedOutStateRender() throws {
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Signed Out"].exists || app.staticTexts["Signed out"].exists)

        for section in ["Dashboard", "Tasks", "Timetable", "EPR", "Account"] {
            XCTAssertTrue(app.staticTexts[section].firstMatch.exists)
        }
    }

    func testSettingsWindowOpens() throws {
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5))

        app.typeKey(",", modifierFlags: [.command])

        XCTAssertTrue(app.staticTexts["Startup"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.checkBoxes["Launch at Login"].exists
                || app.switches["Launch at Login"].exists
                || app.staticTexts["Launch at Login"].exists
        )
        XCTAssertTrue(app.buttons["Save"].exists)
    }

}
