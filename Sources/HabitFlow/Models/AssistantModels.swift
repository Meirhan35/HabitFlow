import Foundation

public struct AssistantPlan: Codable, Equatable {
    public struct Goal: Codable, Equatable {
        public var title: String
        public var unit: String
        public var target: Double
        public var deadline: String
        public var category: String
        public var priority: String
    }
    public struct Milestone: Codable, Equatable, Identifiable {
        public var title: String
        public var due: String
        public var id: String { title + due }
    }
    public struct ProposedHabit: Codable, Equatable, Identifiable {
        public var title: String
        public var frequency: String
        public var days: [Int]
        public var time: String
        public var minimum_version: String
        public var id: String { title + time }
    }
    public struct Idea: Codable, Equatable, Identifiable {
        public var title: String
        public var description: String
        public var url: String?
        public var id: String { title + description }
    }
    public struct RealityCheck: Codable, Equatable {
        public var level: String
        public var comment: String
    }
    public var goal: Goal
    public var milestones: [Milestone]
    public var habits: [ProposedHabit]
    public var ideas: [Idea]
    public var reality_check: RealityCheck

    public func validate(today: String) throws {
        func required(_ text: String) throws {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw AssistantPlanError.invalid }
        }
        try required(goal.title); try required(goal.unit); try required(goal.category)
        guard goal.target.isFinite, goal.target > 0, Self.validDate(goal.deadline), goal.deadline >= today,
              ["high", "medium", "low"].contains(goal.priority),
              (3...6).contains(milestones.count), !habits.isEmpty, (3...5).contains(ideas.count),
              ["ok", "heavy", "too_heavy"].contains(reality_check.level) else { throw AssistantPlanError.invalid }
        try required(reality_check.comment)
        for milestone in milestones {
            try required(milestone.title)
            guard Self.validDate(milestone.due), milestone.due >= today, milestone.due <= goal.deadline else { throw AssistantPlanError.invalid }
        }
        for habit in habits {
            try required(habit.title); try required(habit.minimum_version)
            guard ["daily", "weekdays", "weekly", "custom"].contains(habit.frequency),
                  habit.days.allSatisfy({ (1...7).contains($0) }),
                  Self.validTime(habit.time),
                  !(["weekly", "custom"].contains(habit.frequency) && habit.days.isEmpty) else { throw AssistantPlanError.invalid }
        }
        for idea in ideas {
            try required(idea.title); try required(idea.description)
            if let url = idea.url, (URL(string: url)?.scheme != "https" || URL(string: url)?.host == nil) {
                throw AssistantPlanError.invalid
            }
        }
    }

    private static func validDate(_ value: String) -> Bool {
        guard value.count == 10, let date = DateKeyHelper.date(from: value) else { return false }
        return DateKeyHelper.dateKey(from: date) == value
    }
    private static func validTime(_ value: String) -> Bool {
        let parts = value.split(separator: ":")
        return parts.count == 2 && parts[0].count == 2 && parts[1].count == 2 &&
            (Int(parts[0]) ?? -1) < 24 && (Int(parts[0]) ?? -1) >= 0 &&
            (Int(parts[1]) ?? -1) < 60 && (Int(parts[1]) ?? -1) >= 0
    }
}

public enum AssistantPlanError: LocalizedError {
    case invalid
    public var errorDescription: String? { "Не удалось прочитать план. Попробуйте уточнить запрос." }
}

public struct SavedGoal: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var title: String
    public var unit: String
    public var target: Double
    public var deadline: String
    public var category: String
    public var priority: String
    public var milestones: [AssistantPlan.Milestone]
    public var ideas: [AssistantPlan.Idea]
    public var habitIDs: [UUID]
    public var createdAt: Date = Date()
}

public struct AssistantMessage: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var role: String
    public var text: String
    public var createdAt: Date = Date()
}

public struct AssistantChat: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var title: String = "Новый чат"
    public var messages: [AssistantMessage] = []
    public var plan: AssistantPlan?
    public var questions: [String] = []
    public var saved: Bool = false
    public var createdAt: Date = Date()
}
