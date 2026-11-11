import Foundation

public struct AssistantReply: Decodable {
    public let message: String
    public let questions: [String]
    public let plan: AssistantPlan?

    public func validate(today: String) throws {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              questions.count <= 4,
              questions.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              !questions.isEmpty || plan != nil,
              plan == nil || questions.isEmpty else { throw AssistantPlanError.invalid }
        if !questions.isEmpty && questions.count < 2 { throw AssistantPlanError.invalid }
        try plan?.validate(today: today)
    }
}

public enum GoalAssistantService {
    public static func respond(chat: AssistantChat, context: String, today: String) async throws -> AssistantReply {
        guard let key = GeminiConfiguration.loadAPIKey() else {
            throw NSError(domain: "Assistant", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не найден API-ключ Gemini. Установите GEMINI_API_KEY или добавьте GeminiAPIKey.txt в Resources и пересоберите приложение."])
        }
        guard let promptURL = Bundle.module.url(forResource: "AssistantSystemPrompt", withExtension: "txt"),
              let systemPrompt = try? String(contentsOf: promptURL, encoding: .utf8) else {
            throw NSError(domain: "Assistant", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не найден системный промпт ассистента."])
        }
        let contents: [[String: Any]] = chat.messages.map { message in
            ["role": message.role == "user" ? "user" : "model",
             "parts": [["text": message.text]]]
        }
        let deviceContext = "Регион устройства: \(Locale.current.region?.identifier ?? "неизвестен"); языки устройства: \(Locale.preferredLanguages.joined(separator: ", ")); часовой пояс: \(TimeZone.current.identifier). Это подсказки, а не подтверждённое место жительства."
        let searchResults: String
        if chat.plan == nil {
            searchResults = (try? await findLearningResources(chat: chat, deviceContext: deviceContext, key: key))
                ?? fallbackResources(chat: chat)
        } else {
            searchResults = "Используй уже найденные ссылки в текущем плане, если они ещё подходят."
        }
        var instruction = systemPrompt + "\nСегодня: \(today).\n\(deviceContext)\nТекущие данные пользователя:\n\(context)\nТекущая карточка плана (обновляй её при изменениях):\n\(planJSON(chat.plan))\nРезультаты поиска ресурсов:\n\(searchResults)"
        for attempt in 0...1 {
            var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            request.timeoutInterval = 90
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "systemInstruction": ["parts": [["text": instruction]]],
                "contents": contents,
                "generationConfig": ["responseMimeType": "application/json"]
            ])
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let message = status == 400 || status == 401 || status == 403 ? "Gemini не принял API-ключ или запрос." : status == 404 ? "Модель Gemini 3.8 Flash недоступна для этого ключа." : status == 429 ? "Превышен лимит запросов Gemini. Попробуйте позже." : "Gemini не ответил. Проверьте подключение к интернету."
                throw NSError(domain: "Assistant", code: status, userInfo: [NSLocalizedDescriptionKey: message])
            }
            do {
                let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let candidate = (envelope?["candidates"] as? [[String: Any]])?.first
                let content = candidate?["content"] as? [String: Any]
                let parts = content?["parts"] as? [[String: Any]] ?? []
                let raw = parts.filter { ($0["thought"] as? Bool) != true }
                    .compactMap { $0["text"] as? String }.joined()
                guard !raw.isEmpty,
                      let json = raw.data(using: .utf8) else { throw AssistantPlanError.invalid }
                let reply = try JSONDecoder().decode(AssistantReply.self, from: json)
                try reply.validate(today: today)
                return reply
            } catch {
                if attempt == 0 {
                    let correction = "Предыдущий ответ не прошёл проверку JSON или полей. Верни корректный JSON строго по схеме, проверь сроки, частоты и количество этапов/идей."
                    instruction += "\n" + correction
                } else { throw AssistantPlanError.invalid }
            }
        }
        throw AssistantPlanError.invalid
    }

    private static func planJSON(_ plan: AssistantPlan?) -> String {
        guard let plan, let data = try? JSONEncoder().encode(plan), let text = String(data: data, encoding: .utf8) else { return "нет" }
        return text
    }

    private static func findLearningResources(chat: AssistantChat, deviceContext: String, key: String) async throws -> String {
        let goal = chat.messages.filter { $0.role == "user" }.map(\.text).joined(separator: "\n")
        guard !goal.isEmpty else { return "Нет запроса для поиска." }
        let prompt = "Найди актуальные, качественные и популярные учебные сайты для новичка по запросу пользователя. Учитывай язык и регион, указанные пользователем; системные подсказки используй только если пользователь не указал их. Для Казахстана поищи ресурсы на русском и казахском. Приведи прямые HTTPS-ссылки на конкретные курсы или разделы, язык и краткую причину выбора. Не выдумывай адреса.\nЗапрос: \(goal)\n\(deviceContext)"
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": [["role": "user", "parts": [["text": prompt]]]],
            "tools": [["google_search": [String: String]()]]
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidate = (envelope["candidates"] as? [[String: Any]])?.first else {
            throw AssistantPlanError.invalid
        }
        let parts = (candidate["content"] as? [String: Any])?["parts"] as? [[String: Any]] ?? []
        let summary = parts.filter { ($0["thought"] as? Bool) != true }
            .compactMap { $0["text"] as? String }.joined()
        let chunks = (candidate["groundingMetadata"] as? [String: Any])?["groundingChunks"] as? [[String: Any]] ?? []
        let sources = chunks.compactMap { ($0["web"] as? [String: Any])?["uri"] as? String }
        guard !sources.isEmpty else { throw AssistantPlanError.invalid }
        return "Найденные источники:\n\(sources.prefix(10).joined(separator: "\n"))\nВывод поиска:\n\(summary.prefix(6000))"
    }

    private static func fallbackResources(chat: AssistantChat) -> String {
        let request = chat.messages.filter { $0.role == "user" }.map(\.text).joined(separator: " ").lowercased()
        let isPython = ["python", "питон", "пайтон"].contains { request.contains($0) }
        let mentionsKazakhstan = ["kazakhstan", "казахстан", "қазақстан"].contains { request.contains($0) }
        let statesAnotherResidence = !mentionsKazakhstan &&
            ["i live in ", "i am in ", "я живу в ", "тұрамын"].contains { request.contains($0) }
        let deviceSuggestsKazakhstan = Locale.current.region?.identifier == "KZ" ||
            ["Asia/Almaty", "Asia/Aqtau", "Asia/Aqtobe", "Asia/Atyrau", "Asia/Oral", "Asia/Qostanay", "Asia/Qyzylorda"].contains(TimeZone.current.identifier)
        let isKazakhstan = mentionsKazakhstan || (!statesAnotherResidence && deviceSuggestsKazakhstan)
        guard isPython && isKazakhstan else {
            return "Поиск недоступен и проверенных ссылок для этой темы нет; не добавляй непроверенные адреса."
        }
        return "Проверенный резервный список для новичка в Казахстане (доступность и популярность сейчас не проверены):\nРусский: «Поколение Python», бесплатный курс с практикой — https://stepik.org/course/58852/promo\nКазахский: ITUniver, вводные уроки Python — https://www.ituniver.kz/programming/python-intro/\nВыбери оба языка в идеях плана и не утверждай, что это результаты текущего поиска."
    }
}
