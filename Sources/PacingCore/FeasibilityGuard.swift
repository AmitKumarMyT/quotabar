import Foundation

public struct FeasibilityGuard: Sendable {
    public static let minimumDeltaFiveHour: Double = 20.0
    public static let requiredSamplesForEstimation: Int = 3

    public struct GuardResult: Sendable, Equatable {
        public let isStranded: Bool
        public let estimatedK: Double
        public let isEstimating: Bool
        public let sampleCount: Int
        public let remainingFiveHourPeriods: Int
        public let statusDescription: String
    }

    /// Derives k samples from historical readings where fiveHourPercentUsed shifted by >= 20%
    public static func learnKSamples(from readings: [QuotaReading]) -> [Double] {
        guard readings.count >= 2 else { return [] }
        var samples: [Double] = []

        // Sort by timestamp ascending
        let sorted = readings.sorted { $0.timestamp < $1.timestamp }
        for i in 0..<(sorted.count - 1) {
            let prev = sorted[i]
            let curr = sorted[i + 1]

            guard let prev5h = prev.fiveHourPercentUsed,
                  let curr5h = curr.fiveHourPercentUsed else {
                continue
            }

            let delta5h = abs(curr5h - prev5h)
            let deltaWeekly = curr.weeklyPercentUsed - prev.weeklyPercentUsed

            // Only consider intervals where 5h moved by at least 20 points and weekly advanced
            if delta5h >= minimumDeltaFiveHour && deltaWeekly > 0 {
                // k is the weekly percentage one full (100%) five-hour window burns
                // k = (deltaWeekly / delta5h) * 100
                let calculatedK = (deltaWeekly / delta5h) * 100.0
                if calculatedK > 1.0 && calculatedK <= 100.0 {
                    samples.append(calculatedK)
                }
            }
        }
        return samples
    }

    public static func evaluate(
        currentReading: QuotaReading,
        config: MeterConfig,
        learnedKSamples: [Double],
        currentDate: Date = Date()
    ) -> GuardResult {
        guard config.hasFiveHourWindow else {
            return GuardResult(
                isStranded: false,
                estimatedK: config.defaultK,
                isEstimating: false,
                sampleCount: 0,
                remainingFiveHourPeriods: 0,
                statusDescription: "No 5h window (Guard inactive)"
            )
        }

        let secondsRemaining = max(0, currentReading.weeklyResetDate.timeIntervalSince(currentDate))
        let remainingHours = secondsRemaining / 3600.0
        let remainingFiveHourPeriods = Int(floor(remainingHours / 5.0))

        let isEstimating = learnedKSamples.count < requiredSamplesForEstimation
        let effectiveK: Double
        if isEstimating {
            effectiveK = config.defaultK
        } else {
            effectiveK = learnedKSamples.reduce(0.0, +) / Double(learnedKSamples.count)
        }

        let remainingWeeklyPercent = max(0.0, 100.0 - currentReading.weeklyPercentUsed)
        let maxPossibleWeeklyBurn = Double(remainingFiveHourPeriods) * effectiveK

        // As per PRD: Never declare "Stranded" from default k alone
        let isStranded = !isEstimating && (remainingWeeklyPercent > maxPossibleWeeklyBurn)

        let statusText: String
        if isStranded {
            statusText = "Stranded quota risk: Max burn \(Int(round(maxPossibleWeeklyBurn)))% < Remaining \(Int(round(remainingWeeklyPercent)))%"
        } else if isEstimating {
            statusText = "Guard: Estimating window burn (\(learnedKSamples.count)/\(requiredSamplesForEstimation) pairs)"
        } else {
            statusText = "Guard: Feasible (Est. burn \(Int(round(effectiveK)))%/window)"
        }

        return GuardResult(
            isStranded: isStranded,
            estimatedK: effectiveK,
            isEstimating: isEstimating,
            sampleCount: learnedKSamples.count,
            remainingFiveHourPeriods: remainingFiveHourPeriods,
            statusDescription: statusText
        )
    }
}
