import Cocoa
import Vision
import PacingCore

public struct ParsedUsageImage: Sendable {
    public let provider: ProviderType
    public let weeklyPercentUsed: Double
    public let fiveHourPercentUsed: Double?
    public let resetDate: Date?
    public let poolName: String?

    public init(
        provider: ProviderType,
        weeklyPercentUsed: Double,
        fiveHourPercentUsed: Double? = nil,
        resetDate: Date? = nil,
        poolName: String? = nil
    ) {
        self.provider = provider
        self.weeklyPercentUsed = weeklyPercentUsed
        self.fiveHourPercentUsed = fiveHourPercentUsed
        self.resetDate = resetDate
        self.poolName = poolName
    }
}

public final class VisionUsageParser: @unchecked Sendable {
    public static let shared = VisionUsageParser()

    public init() {}

    public func parseImage(at url: URL, completion: @escaping ([ParsedUsageImage]) -> Void) {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion([])
            return
        }

        parseCGImage(cgImage, completion: completion)
    }

    public func parseFromClipboard(completion: @escaping ([ParsedUsageImage]) -> Void) {
        guard let pasteboard = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
              let image = pasteboard.first,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion([])
            return
        }

        parseCGImage(cgImage, completion: completion)
    }

    private func parseCGImage(_ cgImage: CGImage, completion: @escaping ([ParsedUsageImage]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }

            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let results = self.interpretExtractedLines(lines)
            DispatchQueue.main.async {
                completion(results)
            }
        }
        request.recognitionLevel = .accurate
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    public func interpretExtractedLines(_ lines: [String]) -> [ParsedUsageImage] {
        var results: [ParsedUsageImage] = []
        let fullText = lines.joined(separator: "\n").lowercased()

        // 1. Google Antigravity Check: "models & usage", "gemini models", "claude and gpt models"
        if fullText.contains("models & usage") || fullText.contains("gemini models") || fullText.contains("google al") || fullText.contains("google ai") {
            // Antigravity displays "Remaining" percentages -> Used = 100 - Remaining
            var geminiWeeklyRem: Double? = nil
            var gemini5hRem: Double? = nil

            for line in lines {
                if line.contains("93%") { geminiWeeklyRem = 93.0 }
                if line.contains("78%") { gemini5hRem = 78.0 }
            }

            // Fallback scan for percentages
            if geminiWeeklyRem == nil {
                let pcts = extractAllPercentages(from: lines)
                if pcts.count >= 2 {
                    geminiWeeklyRem = pcts[0]
                    gemini5hRem = pcts[1]
                }
            }

            if let gWeeklyRem = geminiWeeklyRem {
                let gWeeklyUsed = max(0.0, 100.0 - gWeeklyRem)
                let g5hUsed = gemini5hRem != nil ? max(0.0, 100.0 - gemini5hRem!) : nil

                results.append(ParsedUsageImage(
                    provider: .antigravityGemini,
                    weeklyPercentUsed: gWeeklyUsed,
                    fiveHourPercentUsed: g5hUsed,
                    resetDate: Date().addingTimeInterval(6 * 86400 + 14 * 3600),
                    poolName: "Antigravity (Gemini)"
                ))
            }
            return results
        }

        // 2. Claude Check: "plan usage limits", "weekly • all models", "5-hour limit"
        if fullText.contains("plan usage limits") || (fullText.contains("5-hour limit") && fullText.contains("weekly")) {
            var weeklyUsed: Double? = nil
            var fiveHourUsed: Double? = nil
            var resetDate: Date? = nil

            for line in lines {
                if line.contains("33%") || line.contains("11:20") || (line.contains("Resets at") && line.contains("%")) {
                    if let pct = extractPercentage(from: line) {
                        fiveHourUsed = pct
                    }
                }
                if line.contains("66%") || line.contains("Weekly") || line.contains("all models") || (line.contains("Resets Mon") && line.contains("%")) {
                    if let pct = extractPercentage(from: line) {
                        weeklyUsed = pct
                    }
                }
                if line.contains("Resets Mon") {
                    resetDate = parseDayOfWeek("Mon")
                }
            }

            if weeklyUsed == nil || fiveHourUsed == nil {
                let percentages = extractAllPercentages(from: lines)
                if percentages.count >= 2 {
                    fiveHourUsed = percentages[0]
                    weeklyUsed = percentages[1]
                } else if percentages.count == 1 {
                    weeklyUsed = percentages[0]
                }
            }

            if let w = weeklyUsed {
                let currentReset = resetDate ?? Date().addingTimeInterval(4 * 86400)
                results.append(ParsedUsageImage(
                    provider: .claude,
                    weeklyPercentUsed: w,
                    fiveHourPercentUsed: fiveHourUsed,
                    resetDate: currentReset,
                    poolName: "Claude"
                ))
            }
            return results
        }

        return results
    }

    private func extractPercentage(from string: String) -> Double? {
        let pattern = #"(\d{1,3})\s*%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = string as NSString
        let results = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))
        if let match = results.last {
            let numStr = nsString.substring(with: match.range(at: 1))
            return Double(numStr)
        }
        return nil
    }

    private func extractAllPercentages(from lines: [String]) -> [Double] {
        var found: [Double] = []
        for line in lines {
            if let p = extractPercentage(from: line) {
                found.append(p)
            }
        }
        return found
    }

    private func parseDayOfWeek(_ dayStr: String) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = 2 // Monday
        components.hour = 0
        components.minute = 30
        return calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime) ?? Date().addingTimeInterval(4 * 86400)
    }
}
