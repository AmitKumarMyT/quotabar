import Foundation

public struct PacingEngine: Sendable {
    public static let staleDataInterval: TimeInterval = 12 * 3600 // 12 hours

    /// Calculate days left counting today, based on reset date and current date
    public static func calculateDaysLeft(
        resetDate: Date,
        currentDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let startOfToday = calendar.startOfDay(for: currentDate)
        let startOfResetDay = calendar.startOfDay(for: resetDate)

        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfResetDay)
        let diff = components.day ?? 0

        // If today is before reset day, counting today gives diff (minimum 1)
        // If reset is 4 days away including today, returns 4
        return max(1, diff)
    }

    /// Calculate day pacing plan strictly according to PRD formulas:
    /// - Budget = remaining ÷ days left
    /// - Goal = used at start + budget
    /// - Safe mark = start + 70% of budget (rounded down)
    /// - Ease-off mark = start + 87.5% of budget (rounded)
    public static func computePlan(
        usedAtDayStart: Double,
        currentUsed: Double,
        daysLeft: Int,
        lastUpdated: Date?,
        currentDate: Date = Date(),
        guardResult: FeasibilityGuard.GuardResult? = nil
    ) -> DayPacingPlan {
        let remainingWeekly = max(0.0, 100.0 - usedAtDayStart)
        let effectiveDays = max(1, daysLeft)

        // Integer arithmetic matching the PRD examples
        // Budget = remaining ÷ days left
        let rawBudget = remainingWeekly / Double(effectiveDays)
        let budget = Int(floor(rawBudget))

        // Goal = start + budget
        let startInt = Int(round(usedAtDayStart))
        let goal = startInt + budget

        // Safe mark = start + 70% of budget, rounded down
        let safeMark = startInt + Int(floor(Double(budget) * 0.70))

        // Ease-off mark = start + 87.5% of budget, rounded
        let easeOffMark = startInt + Int(round(Double(budget) * 0.875))

        let currentInt = Int(round(currentUsed))
        let roomLeftToday = max(0, goal - currentInt)

        // Age / Stale check
        let isStale: Bool
        if let lastUpdated {
            isStale = currentDate.timeIntervalSince(lastUpdated) > staleDataInterval
        } else {
            isStale = true
        }

        // Status Determination
        let status: PacingStatus
        if isStale {
            status = .oldData
        } else if let guardResult, guardResult.isStranded {
            status = .stranded
        } else if currentInt > goal {
            status = .overGoal
        } else if currentInt >= easeOffMark {
            status = .easeOff
        } else if currentInt >= safeMark {
            status = .pastSafe
        } else {
            status = .onPace
        }

        return DayPacingPlan(
            usedAtDayStart: startInt,
            currentUsed: currentInt,
            daysLeft: effectiveDays,
            budget: budget,
            goal: goal,
            safeMark: safeMark,
            easeOffMark: easeOffMark,
            roomLeftToday: roomLeftToday,
            status: status,
            isStale: isStale,
            lastUpdated: lastUpdated,
            guardStatusText: guardResult?.statusDescription
        )
    }

    /// Detects if a new week rollover has occurred based on reset time or drop in percentage
    public static func isNewWeek(
        previousReading: QuotaReading?,
        newWeeklyPercent: Double,
        newResetDate: Date,
        currentDate: Date = Date()
    ) -> Bool {
        guard let prev = previousReading else { return false }

        // Condition 1: Current date passed the previous weekly reset date
        if currentDate >= prev.weeklyResetDate {
            return true
        }

        // Condition 2: Reset date explicitly changed to future
        if newResetDate.timeIntervalSince(prev.weeklyResetDate) > 24 * 3600 {
            return true
        }

        // Condition 3: Significant drop in weekly usage (reset occurred)
        if newWeeklyPercent < (prev.weeklyPercentUsed - 10.0) {
            return true
        }

        return false
    }
}
