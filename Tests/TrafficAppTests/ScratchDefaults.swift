import Foundation

/// Preferences for one test, kept in a temporary folder of their own.
///
/// A named suite such as `UserDefaults(suiteName: "org.traffic.test.<UUID>")`
/// leaves an empty plist in ~/Library/Preferences after every run: the
/// preferences daemon writes the emptied domain back to disk even after
/// `removePersistentDomain(forName:)`. A suite named by an absolute path is
/// stored at that path instead, so removing its folder removes every trace.
enum ScratchDefaults {
    private static let folderPrefix = "current-defaults-"

    /// A suite name for `UserDefaults(suiteName:)` whose file lives in a new
    /// temporary folder. Pass the same name to `remove(_:)` when the test ends.
    static func makeSuiteName(_ label: String) -> String {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(folderPrefix)\(label)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("defaults").path
    }

    /// Clears the suite and deletes its folder. Only folders made by
    /// `makeSuiteName(_:)` are deleted.
    static func remove(_ suiteName: String) {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        let folder = URL(fileURLWithPath: suiteName).deletingLastPathComponent()
        guard folder.lastPathComponent.hasPrefix(folderPrefix),
              folder.deletingLastPathComponent().standardizedFileURL.path
                == FileManager.default.temporaryDirectory.standardizedFileURL.path
        else { return }
        try? FileManager.default.removeItem(at: folder)
    }
}
