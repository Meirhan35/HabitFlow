import Foundation

enum GroqConfiguration {
    static func loadAPIKey() -> String? {
        guard let url = Bundle.module.url(forResource: "GroqAPIKey", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }
}
