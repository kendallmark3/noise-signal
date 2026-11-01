import Foundation

/// Persists settings and session summaries. Audio never reaches this boundary.
protocol AppDataStoring: Sendable {
    func loadSessions() -> [NoiseSession]
    func saveSessions(_ sessions: [NoiseSession])
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
}

/// JSON in `UserDefaults`. Missing or unreadable data falls back to empty history and default settings.
final class UserDefaultsAppDataStore: AppDataStoring, @unchecked Sendable {
    private enum Key {
        static let sessions = "history.sessions"
        static let settings = "app.settings"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSessions() -> [NoiseSession] {
        load([NoiseSession].self, key: Key.sessions) ?? []
    }

    func saveSessions(_ sessions: [NoiseSession]) {
        save(sessions, key: Key.sessions)
    }

    func loadSettings() -> AppSettings {
        load(AppSettings.self, key: Key.settings) ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        save(settings, key: Key.settings)
    }

    private func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
