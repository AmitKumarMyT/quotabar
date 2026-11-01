import Foundation
import PacingCore

public struct PersistedMeterData: Codable, Sendable {
    public var config: MeterConfig
    public var readings: [QuotaReading]
    public var dayStartSnapshots: [String: Double] // "yyyy-MM-dd": usedPercent
    public var learnedKSamples: [Double]

    public init(
        config: MeterConfig,
        readings: [QuotaReading] = [],
        dayStartSnapshots: [String: Double] = [:],
        learnedKSamples: [Double] = []
    ) {
        self.config = config
        self.readings = readings
        self.dayStartSnapshots = dayStartSnapshots
        self.learnedKSamples = learnedKSamples
    }
}

public struct AppStorageData: Codable, Sendable {
    public var meters: [PersistedMeterData]
    public var showLowestHeadroomOnly: Bool
    public var launchAtLogin: Bool

    public init(
        meters: [PersistedMeterData] = [],
        showLowestHeadroomOnly: Bool = false,
        launchAtLogin: Bool = false
    ) {
        self.meters = meters
        self.showLowestHeadroomOnly = showLowestHeadroomOnly
        self.launchAtLogin = launchAtLogin
    }
}

public final class QuotaStore: @unchecked Sendable {
    public static let shared = QuotaStore()

    public private(set) var meters: [PersistedMeterData] = []
    public var showLowestHeadroomOnly: Bool = false {
        didSet { save() }
    }
    public var launchAtLogin: Bool = false {
        didSet { save() }
    }

    public var onUpdate: (() -> Void)?

    private let storageURL: URL
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let quotaBarDir = appSupport.appendingPathComponent("QuotaBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: quotaBarDir, withIntermediateDirectories: true)
        self.storageURL = quotaBarDir.appendingPathComponent("quota_data.json")

        load()

        if meters.isEmpty {
            setupDefaultMeters()
        }
    }

    private func setupDefaultMeters() {
        let calendar = Calendar.current
        let defaultReset = calendar.date(byAdding: .day, value: 4, to: Date()) ?? Date()

        let claudeConfig = MeterConfig(provider: .claude, defaultK: 20.0)
        let claudeInitialReading = QuotaReading(
            weeklyPercentUsed: 48.0,
            fiveHourPercentUsed: 25.0,
            weeklyResetDate: defaultReset
        )
        let claudeData = PersistedMeterData(
            config: claudeConfig,
            readings: [claudeInitialReading],
            dayStartSnapshots: [todayKey(): 48.0],
            learnedKSamples: [20.0, 20.0, 19.0]
        )

        let agConfig = MeterConfig(provider: .antigravityGemini, defaultK: 20.0)
        let agInitialReading = QuotaReading(
            weeklyPercentUsed: 32.0,
            fiveHourPercentUsed: 30.0,
            weeklyResetDate: defaultReset
        )
        let agData = PersistedMeterData(
            config: agConfig,
            readings: [agInitialReading],
            dayStartSnapshots: [todayKey(): 32.0],
            learnedKSamples: [20.0, 18.0, 22.0]
        )

        self.meters = [claudeData, agData]
        save()
    }

    private func todayKey(for date: Date = Date()) -> String {
        return dateFormatter.string(from: date)
    }

    public func plan(for meter: PersistedMeterData, at currentDate: Date = Date()) -> DayPacingPlan {
        let lastReading = meter.readings.last
        let currentUsed = lastReading?.weeklyPercentUsed ?? 0.0

        let key = todayKey(for: currentDate)
        let usedAtStart = meter.dayStartSnapshots[key] ?? currentUsed

        let resetDate = lastReading?.weeklyResetDate ?? currentDate.addingTimeInterval(4 * 86400)
        let daysLeft = PacingEngine.calculateDaysLeft(resetDate: resetDate, currentDate: currentDate)

        var guardResult: FeasibilityGuard.GuardResult? = nil
        if meter.config.hasFiveHourWindow, let reading = lastReading {
            guardResult = FeasibilityGuard.evaluate(
                currentReading: reading,
                config: meter.config,
                learnedKSamples: meter.learnedKSamples,
                currentDate: currentDate
            )
        }

        return PacingEngine.computePlan(
            usedAtDayStart: usedAtStart,
            currentUsed: currentUsed,
            daysLeft: daysLeft,
            lastUpdated: lastReading?.timestamp,
            currentDate: currentDate,
            guardResult: guardResult
        )
    }

    public func addReading(
        for meterID: UUID,
        weeklyPercent: Double,
        fiveHourPercent: Double?,
        weeklyResetDate: Date,
        at timestamp: Date = Date()
    ) {
        guard let index = meters.firstIndex(where: { $0.config.id == meterID }) else { return }

        var meter = meters[index]
        let previousReading = meter.readings.last

        let isRollover = PacingEngine.isNewWeek(
            previousReading: previousReading,
            newWeeklyPercent: weeklyPercent,
            newResetDate: weeklyResetDate,
            currentDate: timestamp
        )

        let newReading = QuotaReading(
            timestamp: timestamp,
            weeklyPercentUsed: weeklyPercent,
            fiveHourPercentUsed: fiveHourPercent,
            weeklyResetDate: weeklyResetDate
        )

        meter.readings.append(newReading)

        let key = todayKey(for: timestamp)
        if meter.dayStartSnapshots[key] == nil || isRollover {
            meter.dayStartSnapshots[key] = weeklyPercent
        }

        if meter.config.hasFiveHourWindow {
            meter.learnedKSamples = FeasibilityGuard.learnKSamples(from: meter.readings)
        }

        meters[index] = meter
        save()
        onUpdate?()
    }

    public func refreshDaySnapshots(currentDate: Date = Date()) {
        let key = todayKey(for: currentDate)
        for i in 0..<meters.count {
            if meters[i].dayStartSnapshots[key] == nil {
                let latest = meters[i].readings.last?.weeklyPercentUsed ?? 0.0
                meters[i].dayStartSnapshots[key] = latest
            }
        }
        save()
        onUpdate?()
    }

    private func save() {
        let storageData = AppStorageData(
            meters: meters,
            showLowestHeadroomOnly: showLowestHeadroomOnly,
            launchAtLogin: launchAtLogin
        )
        do {
            let data = try JSONEncoder().encode(storageData)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save QuotaBar data: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let storageData = try JSONDecoder().decode(AppStorageData.self, from: data)
            self.meters = storageData.meters
            self.showLowestHeadroomOnly = storageData.showLowestHeadroomOnly
            self.launchAtLogin = storageData.launchAtLogin
        } catch {
            print("Failed to load QuotaBar data: \(error)")
        }
    }
}
