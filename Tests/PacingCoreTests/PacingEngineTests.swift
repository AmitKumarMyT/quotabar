import XCTest
import Foundation
@testable import PacingCore

final class PacingEngineTests: XCTestCase {

    func testClaudePRDWorkedExample() {
        let now = Date()
        let plan = PacingEngine.computePlan(
            usedAtDayStart: 48.0,
            currentUsed: 48.0,
            daysLeft: 4,
            lastUpdated: now,
            currentDate: now
        )

        XCTAssertEqual(plan.budget, 13, "Budget should be floor((100 - 48) / 4) = 13")
        XCTAssertEqual(plan.goal, 61, "Goal should be 48 + 13 = 61")
        XCTAssertEqual(plan.safeMark, 57, "Safe mark should be 48 + floor(13 * 0.70) = 48 + 9 = 57")
        XCTAssertEqual(plan.easeOffMark, 59, "Ease off mark should be 48 + round(13 * 0.875) = 48 + 11 = 59")
        XCTAssertEqual(plan.roomLeftToday, 13, "Room left should be 61 - 48 = 13")
        XCTAssertEqual(plan.status, .onPace)
        XCTAssertFalse(plan.isStale)
    }

    func testAntigravityGeminiPRDWorkedExample() {
        let now = Date()
        let plan = PacingEngine.computePlan(
            usedAtDayStart: 32.0,
            currentUsed: 32.0,
            daysLeft: 4,
            lastUpdated: now,
            currentDate: now
        )

        XCTAssertEqual(plan.budget, 17, "Budget should be floor((100 - 32) / 4) = 17")
        XCTAssertEqual(plan.goal, 49, "Goal should be 32 + 17 = 49")
        XCTAssertEqual(plan.safeMark, 43, "Safe mark should be 32 + floor(17 * 0.70) = 32 + 11 = 43")
        XCTAssertEqual(plan.easeOffMark, 47, "Ease off mark should be 32 + round(17 * 0.875) = 32 + 15 = 47")
        XCTAssertEqual(plan.roomLeftToday, 17, "Room left should be 49 - 32 = 17")
        XCTAssertEqual(plan.status, .onPace)
    }

    func testPacingStatusThresholds() {
        let now = Date()
        let start = 48.0

        let p1 = PacingEngine.computePlan(usedAtDayStart: start, currentUsed: 56.0, daysLeft: 4, lastUpdated: now, currentDate: now)
        XCTAssertEqual(p1.status, .onPace)

        let p2 = PacingEngine.computePlan(usedAtDayStart: start, currentUsed: 57.0, daysLeft: 4, lastUpdated: now, currentDate: now)
        XCTAssertEqual(p2.status, .pastSafe)

        let p3 = PacingEngine.computePlan(usedAtDayStart: start, currentUsed: 59.0, daysLeft: 4, lastUpdated: now, currentDate: now)
        XCTAssertEqual(p3.status, .easeOff)

        let p4 = PacingEngine.computePlan(usedAtDayStart: start, currentUsed: 62.0, daysLeft: 4, lastUpdated: now, currentDate: now)
        XCTAssertEqual(p4.status, .overGoal)

        let oldDate = now.addingTimeInterval(-13 * 3600)
        let p5 = PacingEngine.computePlan(usedAtDayStart: start, currentUsed: 50.0, daysLeft: 4, lastUpdated: oldDate, currentDate: now)
        XCTAssertEqual(p5.status, .oldData)
        XCTAssertTrue(p5.isStale)
    }

    func testFeasibilityGuard() {
        let now = Date()
        let resetDate = now.addingTimeInterval(10 * 3600) // 10 hours left -> 2 periods of 5h
        let config = MeterConfig(provider: .claude, defaultK: 20.0)

        let r1 = QuotaReading(timestamp: now.addingTimeInterval(-6000), weeklyPercentUsed: 20.0, fiveHourPercentUsed: 10.0, weeklyResetDate: resetDate)
        let r2 = QuotaReading(timestamp: now.addingTimeInterval(-4000), weeklyPercentUsed: 25.0, fiveHourPercentUsed: 35.0, weeklyResetDate: resetDate)
        let r3 = QuotaReading(timestamp: now.addingTimeInterval(-2000), weeklyPercentUsed: 30.0, fiveHourPercentUsed: 60.0, weeklyResetDate: resetDate)
        let r4 = QuotaReading(timestamp: now.addingTimeInterval(-500), weeklyPercentUsed: 35.0, fiveHourPercentUsed: 90.0, weeklyResetDate: resetDate)

        let samples = FeasibilityGuard.learnKSamples(from: [r1, r2, r3, r4])
        XCTAssertEqual(samples.count, 3, "Should have extracted 3 samples")

        let currentReading = QuotaReading(weeklyPercentUsed: 30.0, fiveHourPercentUsed: 90.0, weeklyResetDate: resetDate)
        let guardResult = FeasibilityGuard.evaluate(
            currentReading: currentReading,
            config: config,
            learnedKSamples: samples,
            currentDate: now
        )

        XCTAssertTrue(guardResult.isStranded, "Should be marked stranded when remaining quota exceeds possible burn")
    }
}
