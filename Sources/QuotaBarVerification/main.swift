import Foundation
import PacingCore

@main
enum QuotaBarVerification {
    static func main() {
        print("=== Running QuotaBar PacingCore PRD Verifications ===")

        let now = Date()

        // 1. Claude weekly PRD worked example
        // Used at day start = 48%, Days left = 4 -> Budget 13%, Goal 61%, Safe 57%, Ease-off 59%
        let claudePlan = PacingEngine.computePlan(
            usedAtDayStart: 48.0,
            currentUsed: 48.0,
            daysLeft: 4,
            lastUpdated: now,
            currentDate: now
        )

        assert(claudePlan.budget == 13, "Claude budget mismatch: got \(claudePlan.budget), expected 13")
        assert(claudePlan.goal == 61, "Claude goal mismatch: got \(claudePlan.goal), expected 61")
        assert(claudePlan.safeMark == 57, "Claude safeMark mismatch: got \(claudePlan.safeMark), expected 57")
        assert(claudePlan.easeOffMark == 59, "Claude easeOffMark mismatch: got \(claudePlan.easeOffMark), expected 59")
        assert(claudePlan.roomLeftToday == 13, "Claude roomLeftToday mismatch: got \(claudePlan.roomLeftToday), expected 13")
        assert(claudePlan.status == .onPace, "Claude status mismatch: got \(claudePlan.status), expected onPace")
        assert(!claudePlan.isStale, "Claude stale check failed")
        print("✓ Claude Weekly PRD Worked Example: PASSED")

        // 2. Antigravity Gemini weekly PRD worked example
        // Used at day start = 32%, Days left = 4 -> Budget 17%, Goal 49%, Safe 43%, Ease-off 47%
        let agPlan = PacingEngine.computePlan(
            usedAtDayStart: 32.0,
            currentUsed: 32.0,
            daysLeft: 4,
            lastUpdated: now,
            currentDate: now
        )

        assert(agPlan.budget == 17, "AG budget mismatch: got \(agPlan.budget), expected 17")
        assert(agPlan.goal == 49, "AG goal mismatch: got \(agPlan.goal), expected 49")
        assert(agPlan.safeMark == 43, "AG safeMark mismatch: got \(agPlan.safeMark), expected 43")
        assert(agPlan.easeOffMark == 47, "AG easeOffMark mismatch: got \(agPlan.easeOffMark), expected 47")
        assert(agPlan.roomLeftToday == 17, "AG roomLeftToday mismatch: got \(agPlan.roomLeftToday), expected 17")
        assert(agPlan.status == .onPace, "AG status mismatch: got \(agPlan.status), expected onPace")
        print("✓ Antigravity Gemini Weekly PRD Worked Example: PASSED")

        // 3. Threshold transitions
        let start = 48.0
        let pOnPace = PacingEngine.computePlan(usedAtDayStart: start, currentUsed: 56.0, daysLeft: 4, lastUpdated: now, currentDate: now)
        assert(pOnPace.status == .onPace, "Threshold 56% should be onPace")

        let pSafe = PacingEngine.computePlan(usedAtDayStart: start, currentUsed: 57.0, daysLeft: 4, lastUpdated: now, currentDate: now)
        assert(pSafe.status == .pastSafe, "Threshold 57% should be pastSafe")

        let pEase = PacingEngine.computePlan(usedAtDayStart: start, currentUsed: 59.0, daysLeft: 4, lastUpdated: now, currentDate: now)
        assert(pEase.status == .easeOff, "Threshold 59% should be easeOff")

        let pOver = PacingEngine.computePlan(usedAtDayStart: start, currentUsed: 62.0, daysLeft: 4, lastUpdated: now, currentDate: now)
        assert(pOver.status == .overGoal, "Threshold 62% should be overGoal")

        let oldDate = now.addingTimeInterval(-13 * 3600)
        let pOld = PacingEngine.computePlan(usedAtDayStart: start, currentUsed: 50.0, daysLeft: 4, lastUpdated: oldDate, currentDate: now)
        assert(pOld.status == .oldData, "13h old data should be oldData")
        assert(pOld.isStale, "13h old data should be stale")
        print("✓ Pacing Status Threshold Transitions: PASSED")

        // 4. Feasibility Guard & k learning
        let resetDate = now.addingTimeInterval(10 * 3600)
        let config = MeterConfig(provider: .claude, defaultK: 20.0)

        let r1 = QuotaReading(timestamp: now.addingTimeInterval(-6000), weeklyPercentUsed: 20.0, fiveHourPercentUsed: 10.0, weeklyResetDate: resetDate)
        let r2 = QuotaReading(timestamp: now.addingTimeInterval(-4000), weeklyPercentUsed: 25.0, fiveHourPercentUsed: 35.0, weeklyResetDate: resetDate)
        let r3 = QuotaReading(timestamp: now.addingTimeInterval(-2000), weeklyPercentUsed: 30.0, fiveHourPercentUsed: 60.0, weeklyResetDate: resetDate)
        let r4 = QuotaReading(timestamp: now.addingTimeInterval(-500), weeklyPercentUsed: 35.0, fiveHourPercentUsed: 90.0, weeklyResetDate: resetDate)

        let samples = FeasibilityGuard.learnKSamples(from: [r1, r2, r3, r4])
        assert(samples.count == 3, "Samples count mismatch: got \(samples.count), expected 3")

        let currentReading = QuotaReading(weeklyPercentUsed: 30.0, fiveHourPercentUsed: 90.0, weeklyResetDate: resetDate)
        let guardResult = FeasibilityGuard.evaluate(
            currentReading: currentReading,
            config: config,
            learnedKSamples: samples,
            currentDate: now
        )

        assert(guardResult.isStranded, "Should be flagged as stranded")
        print("✓ Feasibility Guard & k Learning: PASSED")

        print("\n🎉 ALL PRD REQUIREMENTS AND MATH MODELS VERIFIED 100% SUCCESSFULLY!\n")
    }
}
