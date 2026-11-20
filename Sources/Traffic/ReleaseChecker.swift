import SwiftUI

@MainActor
final class ReleaseChecker: ObservableObject {
    enum Status: Equatable {
        case idle, checking, checked, failed
    }
    @Published private(set) var status = Status.idle
    @Published private(set) var available: String?
    @Published private(set) var automatic: Bool
    let installed: String
    private let preferences: UserDefaults
    private let fetch: @Sendable () async throws -> String
    private var pending: Task<Void, Never>?
    private var timer: Timer?
    private static let interval: TimeInterval = 86_400

    init(installed: String, preferences: UserDefaults,
         fetch: @escaping @Sendable () async throws -> String = ReleaseChecker.fetchLatest) {
        self.installed = installed
        self.preferences = preferences
        self.fetch = fetch
        automatic = preferences.bool(forKey: "automaticReleaseChecks")
        if let cached = preferences.string(forKey: "latestPublishedVersion"),
           Self.isNewer(cached, than: installed) { available = cached }
    }

    private nonisolated static func parts(_ version: String) -> [Int]? {
        let fields = version.split(separator: ".", omittingEmptySubsequences: false)
        guard fields.count == 3 else { return nil }
        var values: [Int] = []
        for field in fields {
            guard !field.isEmpty, field.utf8.allSatisfy({ (48...57).contains($0) }),
                  let value = Int(field), String(value) == field else { return nil }
            values.append(value)
        }
        return values
    }

    nonisolated static func isNewer(_ version: String, than installed: String) -> Bool {
        guard let remote = parts(version), let local = parts(installed) else { return false }
        return local.lexicographicallyPrecedes(remote)
    }

    nonisolated static func publishedVersion(from data: Data) throws -> String {
        struct Release: Decodable {
            struct Asset: Decodable { let name, state: String }
            let tag_name: String
            let draft, prerelease: Bool
            let assets: [Asset]
        }
        let release = try JSONDecoder().decode(Release.self, from: data)
        let version = String(release.tag_name.dropFirst())
        guard release.tag_name.first == "v", parts(version) != nil, !release.draft, !release.prerelease,
              release.assets.contains(where: { $0.name == "Current.dmg" && $0.state == "uploaded" })
        else { throw URLError(.cannotParseResponse) }
        return version
    }

    nonisolated static func fetchLatest() async throws -> String {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let url = URL(string: "https://api.github.com/repos/Apiruck-Corp/current/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("Current-macOS", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 256 * 1024 else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
        }
        return try publishedVersion(from: data)
    }

    @discardableResult
    func check() -> Task<Void, Never> {
        if let pending { return pending }
        status = .checking
        preferences.set(Date(), forKey: "lastReleaseCheckAttempt")
        let task = Task {
            do {
                let version = try await fetch()
                guard Self.parts(version) != nil, Self.parts(installed) != nil else { throw URLError(.cannotParseResponse) }
                preferences.set(version, forKey: "latestPublishedVersion")
                available = Self.isNewer(version, than: installed) ? version : nil
                status = .checked
            } catch { status = .failed }
            pending = nil
            scheduleAutomaticChecks()
        }
        pending = task
        return task
    }

    func setAutomatic(_ enabled: Bool) {
        automatic = enabled
        preferences.set(enabled, forKey: "automaticReleaseChecks")
        scheduleAutomaticChecks()
    }

    func scheduleAutomaticChecks() {
        timer?.invalidate(); timer = nil
        guard automatic, pending == nil else { return }
        let last = preferences.object(forKey: "lastReleaseCheckAttempt") as? Date
        let delay = min(Self.interval, last?.addingTimeInterval(Self.interval).timeIntervalSinceNow ?? 0)
        if delay <= 0 { check(); return }
        let next = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.automatic else { return }
                self.check()
            }
        }
        next.tolerance = 300
        timer = next
        RunLoop.main.add(next, forMode: .common)
    }
}

struct UpdateSettings: View {
    @ObservedObject var checker: ReleaseChecker
    var body: some View {
        Section {
            HStack {
                Text("Software updates")
                Spacer()
                Button(checker.status == .checking ? "Checking…" : "Check for Updates…") { checker.check() }
                    .disabled(checker.status == .checking)
            }
            if let version = checker.available,
               let url = URL(string: "https://github.com/Apiruck-Corp/current/releases/download/v\(version)/Current.dmg") {
                Link("Download Current \(version)", destination: url)
                Text("Open the downloaded installer and drag Current to Applications.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if checker.status == .checked {
                Text("Current \(checker.installed) is up to date.").font(.callout)
            }
            if checker.status == .failed {
                Text("Couldn’t check GitHub for updates. Try again later.").font(.callout)
            }
            Toggle("Automatically check for updates", isOn: Binding(get: { checker.automatic }, set: checker.setAutomatic))
        } footer: {
            Text("Automatic checks contact GitHub once a day. Available updates appear in the panel. You choose when to download and install them.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct AvailableUpdateButton: View {
    @ObservedObject var checker: ReleaseChecker
    let showAbout: () -> Void
    var body: some View {
        if let version = checker.available {
            Button("Current \(version) available", action: showAbout).buttonStyle(.link)
        }
    }
}
