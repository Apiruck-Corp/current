import XCTest
@testable import Traffic

@MainActor final class ReleaseCheckerTests: XCTestCase {
    func testOnlyStableNumericTagsWithThePublishedInstallerQualify() throws {
        func release(_ tag: String, prerelease: Bool = false, draft: Bool = false, asset: String = "Current.dmg") throws -> String {
            let data = try JSONSerialization.data(withJSONObject: ["tag_name": tag, "draft": draft,
                "prerelease": prerelease, "assets": [["name": asset, "state": "uploaded"]]])
            return try ReleaseChecker.publishedVersion(from: data)
        }
        XCTAssertEqual(try release("v0.10.0"), "0.10.0")
        XCTAssertTrue(ReleaseChecker.isNewer("0.10.0", than: "0.9.12"))
        XCTAssertFalse(ReleaseChecker.isNewer("0.1.3", than: "0.1.5"))
        XCTAssertFalse(ReleaseChecker.isNewer("0.1.5", than: "0.1.5"))
        XCTAssertThrowsError(try release("v0.1.6-rc1"))
        XCTAssertThrowsError(try release("v0.1.6", prerelease: true))
        XCTAssertThrowsError(try release("v0.1.6", draft: true))
        XCTAssertThrowsError(try release("v0.1.6", asset: "Current.dmg.sha256"))
        XCTAssertThrowsError(try release("v0.1.6/other"))
    }

    func testCheckFindsNewReleaseAndRemembersItBetweenLaunches() async throws {
        let suite = "org.traffic.updates.\(UUID())"
        let prefs = UserDefaults(suiteName: suite)!
        defer { prefs.removePersistentDomain(forName: suite) }
        let checker = ReleaseChecker(installed: "0.1.3", preferences: prefs) { "0.1.5" }
        checker.scheduleAutomaticChecks()
        XCTAssertFalse(checker.automatic)
        XCTAssertEqual(checker.status, .idle)
        await checker.check().value
        XCTAssertEqual(checker.available, "0.1.5")
        XCTAssertEqual(checker.status, .checked)
        checker.setAutomatic(true)
        let restarted = ReleaseChecker(installed: "0.1.3", preferences: prefs) { throw URLError(.notConnectedToInternet) }
        restarted.scheduleAutomaticChecks()
        XCTAssertTrue(restarted.automatic)
        XCTAssertEqual(restarted.status, .idle)
        XCTAssertEqual(restarted.available, "0.1.5")
        await restarted.check().value
        XCTAssertEqual(restarted.status, .failed)
        let retry = try XCTUnwrap(prefs.object(forKey: "nextReleaseCheck") as? Date)
        XCTAssertEqual(retry.timeIntervalSinceNow, 3600, accuracy: 5)
        XCTAssertEqual(restarted.available, "0.1.5")
        restarted.setAutomatic(false)
        checker.setAutomatic(false)
        let upgraded = ReleaseChecker(installed: "0.1.5", preferences: prefs) { "0.1.5" }
        await upgraded.check().value
        XCTAssertNil(upgraded.available)
        XCTAssertEqual(upgraded.status, .checked)
    }
}
