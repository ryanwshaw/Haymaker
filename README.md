# CourseIQ

Track your rounds. Analyze your game. Earn badges.

CourseIQ is a native iOS app for golfers who want detailed hole-by-hole tracking, rich analytics, and a fun badge system inspired by Halo. Log every shot, see where your game is strong (and weak), and compete with friends.

## Agent-First Development

This repo is designed for AI-assisted development. The codebase, documentation, and tooling are structured so that coding agents (Cursor, Codex, etc.) can be productive contributors.

### How It Works

**Start here:** [`AGENTS.md`](AGENTS.md) is the primary entry point for any agent. It contains the tech stack, build commands, file structure, and conventions.

**Architecture:** [`ARCHITECTURE.md`](ARCHITECTURE.md) maps out the codebase — models, views, managers, and how data flows.

**Badge ideas:** [`BADGES.md`](BADGES.md) tracks all planned and implemented badge achievements.

### Key Documents

| Document | Purpose |
|----------|---------|
| [`AGENTS.md`](AGENTS.md) | Agent entry point — commands, rules, conventions |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Codebase map, layer boundaries, data flows |
| [`BADGES.md`](BADGES.md) | Badge achievement tracker (ideas + implemented) |
| [`docs/product-spec.md`](docs/product-spec.md) | Product vision, features, and roadmap |

## Features

**Hole-by-Hole Tracking** — Log drive result, approach distance/result, short game, putts, and penalties for every hole. Par 3s get a streamlined flow.

**Multi-Course Support** — Add courses via scorecard photo (OCR) or manually. Select course and tees when starting a round.

**Rich Analytics** — Scoring trends, score distribution, per-hole averages, heat maps, approach-by-distance breakdowns. Filter by course and tees.

**Badge System** — Halo-inspired badges that pop up in real-time as you log holes. "Double Kill" for back-to-back birdies, "SHAI-HULUD" for up-and-down from a greenside bunker, and many more planned.

**Social** — Add friends, compare stats head-to-head, view hole-by-hole breakdowns filtered by course.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI Framework | SwiftUI |
| Persistence | SwiftData |
| Cloud (future) | CloudKit |
| Charts | Swift Charts |
| Minimum iOS | 17.0 |
| IDE | Xcode 16+ |

## Prerequisites

- macOS with Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- iOS 17+ device or simulator

## Setup

1. Clone the repository:
   ```bash
   git clone git@github.com:ryanwshaw/Haymaker.git
   cd Haymaker
   ```

2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

3. Open in Xcode:
   ```bash
   open GolfTracker.xcodeproj
   ```

4. Select your target (simulator or device) and run.

> **Note:** Personal (free) Apple Developer accounts cannot use iCloud entitlements. The app handles this gracefully — all local features work, and the Social tab shows an iCloud availability banner.

## Project Structure

```
GolfTracker/
├── GolfTracker/
│   ├── Assets.xcassets/     # App icon, images, badge assets
│   ├── Models/              # SwiftData models + managers
│   │   ├── Badge.swift      # Badge types, detection, persistence
│   │   ├── CloudKitManager.swift
│   │   ├── Course.swift     # Course + hole definitions
│   │   ├── HoleScore.swift  # Per-hole score data
│   │   ├── Round.swift      # Round model
│   │   └── ...
│   ├── Views/               # SwiftUI views
│   │   ├── ActiveRoundView.swift
│   │   ├── HomeView.swift
│   │   ├── StatsView.swift
│   │   ├── SocialView.swift
│   │   ├── BadgePopupView.swift
│   │   └── ...
│   ├── ContentView.swift    # Root navigation (header + page tabs)
│   ├── GolfTrackerApp.swift # App entry point, ModelContainer setup
│   ├── MockData.swift       # 20 sample rounds for testing
│   └── Theme.swift          # Colors, animations, haptics
├── docs/                    # Product specs, design docs
├── AGENTS.md                # Agent guide
├── ARCHITECTURE.md          # Codebase architecture
├── BADGES.md                # Badge ideas tracker
├── project.yml              # XcodeGen spec
└── .gitignore
```
