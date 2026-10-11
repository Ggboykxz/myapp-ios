import XCTest

final class MyAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsListAndTitle() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.navigationBars["MyApp"].waitForExistence(timeout: 5),
            "L'écran principal doit s'afficher au lancement."
        )
    }

    @MainActor
    func testAddItemFlow() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Nouvel élément"].tap()
        XCTAssertTrue(app.navigationBars["Nouvel élément"].waitForExistence(timeout: 5))

        let titleField = app.textFields["Ex. Rendez-vous dentiste"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Item de test UI")

        app.buttons["Ajouter"].tap()

        // L'élément fusionne titre/date/notes en un seul axe d'accessibilité
        // : on cherche donc par contains plutôt que par égalité stricte.
        let newRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Item de test UI")
        ).firstMatch
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
    }
}
