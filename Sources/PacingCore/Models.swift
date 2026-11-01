import Foundation

public enum ProviderType: String, Codable, Sendable, CaseIterable {
    case claude = "Claude"
    case antigravityGemini = "Antigravity (Gemini)"
    case antigravityClaude = "Antigravity (Claude)"

    public var shortLabel: String {
        switch self {
        case .claude:
            return "C"
        case .antigravityGemini:
            return "A"
        case .antigravityClaude:
            return "A-C"
        }
    }

    public var defaultHasFiveHourWindow: Bool {
        return true
    }
}

public enum PacingStatus: String, Codable, Sendable {
    case onPace = "On pace"
    case pastSafe = "Past safe"
    case easeOff = "Ease off"
    case overGoal = "Over goal"
    case stranded = "Stranded"
    case oldData = "Old data"

    /// SF Symbol name representing status
    public var sfSymbol: String {
        switch self {
        case .onPace, .pastSafe:
            return "circle.fill"
        case .easeOff, .overGoal:
            return "triangle.fill"
        case .stranded:
            return "square"
        case .oldData:
            return "minus"
        }
    }
}

public struct QuotaReading: Codable, Sendable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let weeklyPercentUsed: Double
    public let fiveHourPercentUsed: Double?
    public let weeklyResetDate: Date

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        weeklyPercentUsed: Double,
        fiveHourPercentUsed: Double? = nil,
        weeklyResetDate: Date
    ) {
        self.id = id
        self.timestamp = timestamp
        self.weeklyPercentUsed = weeklyPercentUsed
        self.fiveHourPercentUsed = fiveHourPercentUsed
        self.weeklyResetDate = weeklyResetDate
    }
}

public struct MeterConfig: Codable, Sendable, Identifiable {
    public let id: UUID
    public var provider: ProviderType
    public var name: String
    public var hasFiveHourWindow: Bool
    public var defaultK: Double // weekly % burned per 5h window (default ~20.0%)

    public init(
        id: UUID = UUID(),
        provider: ProviderType,
        name: String? = nil,
        hasFiveHourWindow: Bool? = nil,
        defaultK: Double = 20.0
    ) {
        self.id = id
        self.provider = provider
        self.name = name ?? provider.rawValue
        self.hasFiveHourWindow = hasFiveHourWindow ?? provider.defaultHasFiveHourWindow
        self.defaultK = defaultK
    }
}

public struct DayPacingPlan: Sendable, Equatable {
    public let usedAtDayStart: Int
    public let currentUsed: Int
    public let daysLeft: Int
    public let budget: Int
    public let goal: Int
    public let safeMark: Int
    public let easeOffMark: Int
    public let roomLeftToday: Int
    public let status: PacingStatus
    public let isStale: Bool
    public let lastUpdated: Date?
    public let guardStatusText: String?

    public init(
        usedAtDayStart: Int,
        currentUsed: Int,
        daysLeft: Int,
        budget: Int,
        goal: Int,
        safeMark: Int,
        easeOffMark: Int,
        roomLeftToday: Int,
        status: PacingStatus,
        isStale: Bool,
        lastUpdated: Date?,
        guardStatusText: String? = nil
    ) {
        self.usedAtDayStart = usedAtDayStart
        self.currentUsed = currentUsed
        self.daysLeft = daysLeft
        self.budget = budget
        self.goal = goal
        self.safeMark = safeMark
        self.easeOffMark = easeOffMark
        self.roomLeftToday = roomLeftToday
        self.status = status
        self.isStale = isStale
        self.lastUpdated = lastUpdated
        self.guardStatusText = guardStatusText
    }
}
