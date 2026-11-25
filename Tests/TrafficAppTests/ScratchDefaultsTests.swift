import Foundation
import XCTest

/// Tests need preferences of their own. A named suite leaves an empty file in
/// ~/Library/Preferences on every run, so tests use scratch preferences that
/// live, and die, in a temporary folder.
final class ScratchDefaultsTests: XCTestCase {
    func testScratchPreferencesWorkAndLeaveNothingBehind() throws {
        let suite = ScratchDefaults.makeSuiteName("scratch-check")
        let folder = URL(fileURLWithPath: suite).deletingLastPathComponent()
        let preferences = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences", isDirectory: true)

        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set(7, forKey: "value")
        // A second handle on the same suite sees the value, as a relaunch would.
        XCTAssertEqual(UserDefaults(suiteName: suite)?.integer(forKey: "value"), 7)
        // The value is on disk in the scratch folder, not only in memory.
        defaults.synchronize()
        XCTAssertEqual(NSDictionary(contentsOfFile: suite + ".plist")?["value"] as? Int, 7)

        ScratchDefaults.remove(suite)
        CFPreferencesAppSynchronize(suite as CFString)

        XCTAssertNil(UserDefaults(suiteName: suite)?.object(forKey: "value"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: preferences.path)
            .filter { $0.contains(folder.lastPathComponent) }
        XCTAssertEqual(leftovers, [])
    }

    func testRemoveNeverDeletesAFolderItDidNotMake() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-scratch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        ScratchDefaults.remove(folder.appendingPathComponent("defaults").path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
    }
}
