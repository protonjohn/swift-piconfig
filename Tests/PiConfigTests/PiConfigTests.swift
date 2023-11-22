import XCTest
@testable import PiConfig

final class PiConfigTests: XCTestCase {
    func testNothingIsOnFire() throws {
        let piConfig = """
        // Header comment section. Contains comments about the file and things.
        // The header comment could have more than one line.

        // A line break and then another comment shouldn't cause any problems.
        
        product = widget // A comment at the end should be acceptable.
        // Comments between items should also be okay.
        product_name = FancyWidget
        scheme = $(product_name)-$(human_platform)

        // What about a comment here, in the middle?

        // With multiple ones?

        project_dir = apps/$(platform)
        destination = generic/platform=$(human_platform)

        team_name[platform=pc] = International Widgets Company, Ltd.
        human_platform[platform=pc] = Personal Computer
        team_name[platform=mac] = Super Groovy Widget Co-op
        human_platform[platform=mac] = Shiny Wedge

        binaries[platform=pc] = $(product),$(product)-launcher,$(product)-updater
        binaries[platform=mac] = $(product),com.$(product).launcher,com.$(product).updater
        product[platform=pc][configuration=Staging] = $(inherited).debug

        disable_dependency_updates[CI] = YES
        build_path[CI][!test_without_building] = ~/
        """

        let parsed = try PiConfig.parser.parse(piConfig)
        let ingested = try parsed.ingest()

        let values = try ingested.eval(initialValues: [
            "platform": "pc",
            "configuration": "Staging",
            "CI": "any truthy value",
        ])

        func assert(_ key: PiConfig.Property, _ value: String?) {
            XCTAssertEqual(values[key], value)
        }

        assert("platform", "pc")
        assert("configuration", "Staging")
        assert("CI", "any truthy value")
        assert("binaries", "widget.debug,widget.debug-launcher,widget.debug-updater")
        assert("team_name", "International Widgets Company, Ltd.")
        assert("disable_dependency_updates", "YES")
        assert("build_path", "~/")
    }
}
