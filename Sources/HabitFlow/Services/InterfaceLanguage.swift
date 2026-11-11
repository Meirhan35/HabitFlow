import Foundation

/// Presentation only: persisted model values and user-created content retain their original text.
public enum L10n {
    public static var language: String { UserDefaults.standard.string(forKey: "interfaceLanguage") == "ru" ? "ru" : "en" }
    public static var locale: Locale { Locale(identifier: language == "ru" ? "ru_RU" : "en_US") }
    private static let entries: [String: [String: String]] = {
        guard let url = Bundle.module.url(forResource: "InterfaceTranslations", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return result
    }()
    private static let patterns: [(NSRegularExpression, String, [String: String])] = entries.compactMap { source, values in
        guard source.contains("{{0}}") else { return nil }
        var pattern = NSRegularExpression.escapedPattern(for: source)
        for index in 0..<20 {
            pattern = pattern.replacingOccurrences(of: NSRegularExpression.escapedPattern(for: "{{\(index)}}"), with: "(.*?)")
        }
        guard let regex = try? NSRegularExpression(pattern: "^" + pattern + "$", options: [.dotMatchesLineSeparators]) else { return nil }
        return (regex, source, values)
    }.sorted { $0.1.count > $1.1.count }
    public static func tr(_ text: String) -> String {
        translate(text, depth: 0)
    }
    private static func translate(_ text: String, depth: Int) -> String {
        if let value = entries[text]?[language] { return value }
        guard depth < 3 else { return text }
        let range = NSRange(text.startIndex..., in: text)
        for (regex, _, values) in patterns {
            guard let match = regex.firstMatch(in: text, range: range), var result = values[language] else { continue }
            for index in 1..<match.numberOfRanges {
                if let capture = Range(match.range(at: index), in: text) {
                    result = result.replacingOccurrences(of: "{{\(index - 1)}}", with: translate(String(text[capture]), depth: depth + 1))
                }
            }
            return result
        }
        return text
    }
}
