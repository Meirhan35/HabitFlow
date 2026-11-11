import Foundation

public struct AssistantReply: Decodable {
    public let message: String
    public let questions: [String]
    public let plan: AssistantPlan?

    public func validate(today: String) throws {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              questions.count <= 4,
              questions.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              !questions.isEmpty || plan != nil else { throw AssistantPlanError.invalid }
        if !questions.isEmpty && questions.count < 2 { throw AssistantPlanError.invalid }
        try plan?.validate(today: today)
    }
}

public enum GoalAssistantService {
    public static func respond(chat: AssistantChat, context: String, today: String) async throws -> AssistantReply {
        guard let key = GroqConfiguration.loadAPIKey() else {
            throw NSError(domain: "Assistant", code: 1, userInfo: [NSLocalizedDescriptionKey: "Не найден файл GroqAPIKey.txt. Добавьте ключ в Resources и пересоберите приложение."])
        }
        guard let promptURL = Bundle.module.url(forResource: "AssistantSystemPrompt", withExtension: "txt"),
              let systemPrompt = try? String(contentsOf: promptURL, encoding: .utf8) else {
            throw NSError(domain: "Assistant", code: 2, userInfo: [NSLocalizedDescriptionKey: "Не найден системный промпт ассистента."])
        }
        var messages: [[String: String]] = []
        for message in chat.messages {
            messages.append(["role": message.role == "user" ? "user" : "assistant", "content": message.text])
        }
        let instruction = systemPrompt + "\nСегодня: \(today).\nТекущие данные пользователя:\n\(context)\nТекущая карточка плана (обновляй её при изменениях):\n\(planJSON(chat.plan))"
        messages.insert(["role": "system", "content": instruction], at: 0)
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "openai/gpt-oss-20b",
            "messages": messages,
            "response_format": ["type": "json_object"]
        ])
        for attempt in 0...1 {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let message = status == 401 ? "Groq не принял API-ключ." : status == 429 ? "Превышен лимит запросов Groq. Попробуйте позже." : "Groq не ответил. Проверьте подключение к интернету."
                throw NSError(domain: "Assistant", code: status, userInfo: [NSLocalizedDescriptionKey: message])
            }
            do {
                let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let choice = (envelope?["choices"] as? [[String: Any]])?.first
                let content = choice?["message"] as? [String: Any]
                guard let raw = content?["content"] as? String,
                      let json = raw.data(using: .utf8) else { throw AssistantPlanError.invalid }
                let reply = try JSONDecoder().decode(AssistantReply.self, from: json)
                try reply.validate(today: today)
                return reply
            } catch {
                if attempt == 0 {
                    let correction = "Предыдущий ответ не прошёл проверку JSON или полей. Верни корректный JSON строго по схеме, проверь сроки, частоты и количество этапов/идей."
                    var body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
                    var revised = body["messages"] as! [[String: String]]
                    revised[0]["content", default: ""] += "\n" + correction
                    body["messages"] = revised
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                } else { throw AssistantPlanError.invalid }
            }
        }
        throw AssistantPlanError.invalid
    }

    private static func planJSON(_ plan: AssistantPlan?) -> String {
        guard let plan, let data = try? JSONEncoder().encode(plan), let text = String(data: data, encoding: .utf8) else { return "нет" }
        return text
    }
}
