import Foundation

public struct ClaudeStatuslinePayload: Codable, Sendable {
    public let weeklyPercentUsed: Double
    public let fiveHourPercentUsed: Double?
    public let resetDate: Date?
    public let timestamp: Date

    public init(
        weeklyPercentUsed: Double,
        fiveHourPercentUsed: Double? = nil,
        resetDate: Date? = nil,
        timestamp: Date = Date()
    ) {
        self.weeklyPercentUsed = weeklyPercentUsed
        self.fiveHourPercentUsed = fiveHourPercentUsed
        self.resetDate = resetDate
        self.timestamp = timestamp
    }
}

public final class ClaudeFeedWatcher: @unchecked Sendable {
    private let feedURL: URL
    private var timer: Timer?
    private var lastProcessedTimestamp: TimeInterval = 0
    public var onFeedUpdated: ((ClaudeStatuslinePayload) -> Void)?

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let quotaBarDir = appSupport.appendingPathComponent("QuotaBar", isDirectory: true)
        self.feedURL = quotaBarDir.appendingPathComponent("claude_feed.json")

        // Poll every 3 seconds for file updates (low overhead, immune to directory inode recreation)
        self.timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.checkFeedFile()
        }
        
        checkFeedFile()
    }

    public func checkFeedFile() {
        guard FileManager.default.fileExists(atPath: feedURL.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: feedURL.path),
              let modDate = attrs[.modificationDate] as? Date else {
            return
        }

        let modTimestamp = modDate.timeIntervalSince1970
        guard modTimestamp > lastProcessedTimestamp else { return }

        guard let data = try? Data(contentsOf: feedURL),
              let payload = parseJSON(data: data) else {
            return
        }

        lastProcessedTimestamp = modTimestamp
        DispatchQueue.main.async { [weak self] in
            self?.onFeedUpdated?(payload)
        }
    }

    private func parseJSON(data: Data) -> ClaudeStatuslinePayload? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        var weekly: Double? = nil
        var fiveHour: Double? = nil
        var reset: Date? = nil

        if let w = obj["weeklyPercentUsed"] as? Double { weekly = w }
        else if let wStr = obj["weeklyPercentUsed"] as? String, let w = Double(wStr) { weekly = w }
        else if let w = obj["weekly_percent"] as? Double { weekly = w }

        if let f = obj["fiveHourPercentUsed"] as? Double { fiveHour = f }
        else if let fStr = obj["fiveHourPercentUsed"] as? String, let f = Double(fStr) { fiveHour = f }
        else if let f = obj["five_hour_percent"] as? Double { fiveHour = f }

        if let rateLimits = obj["rate_limits"] as? [String: Any] {
            if let weeklyDict = rateLimits["weekly"] as? [String: Any], let p = weeklyDict["percent_used"] as? Double {
                weekly = p
            }
            if let fiveHDict = rateLimits["five_hour"] as? [String: Any], let p = fiveHDict["percent_used"] as? Double {
                fiveHour = p
            }
        }

        guard let weeklyVal = weekly else { return nil }

        if let resetTimestamp = obj["reset_date"] as? Double {
            reset = Date(timeIntervalSince1970: resetTimestamp)
        } else if let resetStr = obj["reset_date"] as? String {
            let isoFormatter = ISO8601DateFormatter()
            reset = isoFormatter.date(from: resetStr)
        }

        return ClaudeStatuslinePayload(
            weeklyPercentUsed: weeklyVal,
            fiveHourPercentUsed: fiveHour,
            resetDate: reset,
            timestamp: Date()
        )
    }

    deinit {
        timer?.invalidate()
    }
}
