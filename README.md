# QuotaBar: Mac Menu Bar Quota Monitor for Claude & Google Antigravity

[![Platform: macOS 14+](https://img.shields.io/badge/Platform-macOS%2014%2B%20%7C%2026%20%7C%2027-blue.svg?style=flat-square&logo=apple)](https://www.apple.com/macos/)
[![Swift: 5.9 - 6+](https://img.shields.io/badge/Swift-5.9%20%7C%206%2B-orange.svg?style=flat-square&logo=swift)](https://swift.org)
[![Privacy: 100% Local](https://img.shields.io/badge/Privacy-100%25%20On--Device-success.svg?style=flat-square)](https://github.com/AmitKumarMyT/quotabar)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)

> **Know at a glance how much weekly AI quota you can safely burn today.**  
> Monitor Claude Code and Google Antigravity side by side right from your Mac menu bar.

---

## ⚡ The Problem

Both **Claude (Pro/Max)** and **Google Antigravity (Pro/Ultra)** enforce strict weekly quota ceilings alongside rolling 5-hour rate limits. 
- You have to navigate to separate dashboards or terminal commands to check your standing.
- It’s easy to accidentally burn through your entire week's quota by Tuesday, or get locked out right before critical deadlines.
- If you fall behind on usage near the end of the week, the 5-hour rate limits can make it mathematically impossible to spend the rest of your week’s quota (**stranded quota**).

**QuotaBar** solves this by living in your menu bar as a concise, glanceable number:
```
C 13 · A 17
```
*(Claude: 13% room today · Antigravity: 17% room today)*

Clicking the label reveals a **native dark glass popover** with live capsule meters, today's goal, safe marks, ease-off warnings, and feasibility guards.

---

## ✨ Features

- **Side-by-Side Monitoring**: Track Claude and Google Antigravity simultaneously.
- **Glanceable Menu Bar Label**: Displays remaining daily headroom in under a second (`C 13 · A 17`).
- **Mathematical Daily Pacing Model**:
  - **Daily Budget**: $\lfloor \frac{\text{Remaining Weekly Quota}}{\text{Days Left}} \rfloor$
  - **Goal Mark**: Target percentage ceiling for today.
  - **Safe Mark**: $70\%$ of today’s budget (On pace).
  - **Ease-Off Mark**: $87.5\%$ of today’s budget (Warning to slow down).
- **Feasibility Guard**: Continuously samples and learns $k$ (weekly percentage burned per 5-hour window) from delta pairs ($\ge 20\%$). Warns you if remaining 5h windows won't be enough to deplete the quota before the week resets.
- **Zero Credentials & 100% Privacy**:
  - No login, no tokens, no OAuth, no API keys, no telemetry, no tracking.
  - All readings and snapshots stay entirely on your Mac in `~/Library/Application Support/QuotaBar/`.
- **macOS Dark Glass Design**:
  - Built with native vibrancy and frosted material.
  - High-contrast text scrim for WCAG AAA readability across light and dark wallpapers.
  - Continuous 4-mark capsule progress bar with tomorrow's headroom tail.
- **Inline Quick Entry**:
  - Update readings in seconds right inside the card.
  - Press `Return` to save and `Esc` to cancel.
- **Low Energy Footprint**:
  - Runs with `LSUIElement = true` (menu-bar only, no Dock icon).
  - Updates only on day boundaries, Mac wake events, or a light 15-minute timer. Zero continuous CPU polling.

---

## 📐 How the Numbers are Calculated

| Meter | Used at Day Start | Days Left | Today's Budget | Today's Goal | Safe Mark (70%) | Ease-Off Mark (87.5%) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **Claude Weekly** | 48% | 4 | **13%** | **61%** | 57% | 59% |
| **Antigravity Gemini** | 32% | 4 | **17%** | **49%** | 43% | 47% |

*The app automatically detects new-week rollovers whenever your reset date passes or your percentage resets.*

---

## 🚀 Installation

### Option 1: One-Line Terminal Installer
Clone and install directly into `/Applications`:
```bash
git clone https://github.com/AmitKumarMyT/quotabar.git
cd quotabar
./install.sh
```

### Option 2: Pre-built DMG
Download the latest `QuotaBar-Installer.dmg` from the [Releases](https://github.com/AmitKumarMyT/quotabar/releases) page, open it, and drag **QuotaBar** into your **Applications** folder.

---

## 🛠️ Building from Source

Requirements:
- macOS 14.0 or later (Tested on macOS 14, 15, 26, and 27)
- Xcode Command Line Tools or Swift 5.9+

```bash
# Clone the repository
git clone https://github.com/AmitKumarMyT/quotabar.git
cd quotabar

# Run mathematical verification test suite
swift run QuotaBarVerification

# Build release binary
swift build -c release
```

---

## 🔒 Privacy & Compliance

- **Zero Network Calls**: QuotaBar never communicates with Anthropic, Google, or any remote server.
- **Zero Credential Storage**: QuotaBar never prompts for passwords, session cookies, or tokens.
- **Terms Compliant**: Completely avoids scraping, reverse engineering internal APIs, or intermediating OAuth flows.

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
