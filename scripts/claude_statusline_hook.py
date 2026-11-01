#!/usr/bin/env python3
"""
Claude Code Statusline Hook for QuotaBar
Automatically forwards Claude Code rate limit / session telemetry to QuotaBar's local feed.
"""
import sys
import os
import json
import time

def main():
    feed_dir = os.path.expanduser("~/Library/Application Support/QuotaBar")
    os.makedirs(feed_dir, exist_ok=True)
    feed_file = os.path.join(feed_dir, "claude_feed.json")

    # Read stdin passed from Claude Code
    try:
        input_data = sys.stdin.read()
        if not input_data.strip():
            return
        
        payload = json.loads(input_data)
        
        # Extract rate limits
        weekly_percent = None
        five_hour_percent = None
        reset_timestamp = None

        # Format 1: Direct or nested
        if "rate_limits" in payload:
            rl = payload["rate_limits"]
            if "weekly" in rl and "percent_used" in rl["weekly"]:
                weekly_percent = float(rl["weekly"]["percent_used"])
            if "five_hour" in rl and "percent_used" in rl["five_hour"]:
                five_hour_percent = float(rl["five_hour"]["percent_used"])
            if "weekly" in rl and "resets_at" in rl["weekly"]:
                reset_timestamp = rl["weekly"]["resets_at"]
        elif "weeklyPercentUsed" in payload:
            weekly_percent = float(payload["weeklyPercentUsed"])
            five_hour_percent = float(payload.get("fiveHourPercentUsed", 0))

        if weekly_percent is not None:
            out_data = {
                "weeklyPercentUsed": weekly_percent,
                "fiveHourPercentUsed": five_hour_percent,
                "reset_date": reset_timestamp,
                "timestamp": time.time()
            }
            # Atomic write
            temp_file = feed_file + ".tmp"
            with open(temp_file, "w") as f:
                json.dump(out_data, f)
            os.replace(temp_file, feed_file)

    except Exception:
        pass

if __name__ == "__main__":
    main()
