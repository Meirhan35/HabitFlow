import Foundation

enum GeminiConfiguration {
    static func loadAPIKey() -> String? {
        if let key = ProcessInfo.processInfo.environment["GEMINI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            return key
        }
        guard let url = Bundle.module.url(forResource: "GeminiAPIKey", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty ? nil : key
    }
}
