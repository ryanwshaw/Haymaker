# Architecture

<!-- last-verified: 2026-03-12 -->

> Top-level map of the CourseIQ codebase. Read this to understand where code lives, how layers connect, and where to put new code.

## Repository Layout

```
GolfTracker/
├── GolfTracker/
│   ├── Assets.xcassets/        # Images, app icon, badge assets, colors
│   ├── Models/                 # Data layer — SwiftData models + managers
│   ├── Views/                  # UI layer — SwiftUI views
│   ├── ContentView.swift       # Root view — header, page tabs, navigation
│   ├── GolfTrackerApp.swift    # App entry, ModelContainer, seed data
│   ├── MockData.swift          # Sample data generator (20 rounds)
│   └── Theme.swift             # AppTheme colors, animations, haptics
├── docs/                       # Product specs and design documents
├── project.yml                 # XcodeGen project definition
└── BADGES.md                   # Badge achievement tracker
```

## Layer Boundaries

Code flows in one direction: **Models → Views → ContentView**

```
Models (data + logic)
  ↓
Views (UI components)
  ↓
ContentView (root navigation)
  ↓
GolfTrackerApp (entry point)
```

### Models/

SwiftData `@Model` classes and singleton managers. Pure data and business logic — no UI imports except where `Color` is needed for display properties.

| File | Purpose |
|------|---------|
| `Course.swift` | Course model — name, logo, photo, tees, holes. `CourseHole` for per-hole data (par, yardages, handicap). `CourseTeeInfo` for tee definitions. |
| `Round.swift` | Round model — date, tee, completion status, scoring aggregates (`totalScore`, `scoreToPar`, `fairwayPct`, `girPct`). |
| `HoleScore.swift` | Per-hole data — score, putts, tee/approach/chip results, clubs used, approach distance, penalties. Computed `par`, `hitGreen`, `hitFairway`. |
| `Badge.swift` | `BadgeType` enum, `EarnedBadge` struct, `BadgeManager` singleton — detection logic, session dedup, UserDefaults persistence. |
| `CloudKitManager.swift` | CloudKit integration for social features — user profiles, friendships, round sharing. Lazy container init, graceful degradation without iCloud entitlements. |
| `StatsEngine.swift` | Pure computation — takes rounds array, produces aggregated stats (averages, percentages, hole-by-hole, approach-by-distance). |
| `BagManager.swift` | Club bag management — persisted in UserDefaults, editable by user. |
| `Haymaker.swift` | Seed data for the default course (Haymaker Golf Course). |

### Views/

SwiftUI views. Each view handles one screen or major UI section. Views read from SwiftData via `@Query` or receive models as parameters.

| File | Purpose |
|------|---------|
| `HomeView.swift` | Rounds tab — onboarding, in-progress card, new round button, round history. Also contains `CoursePickerView`, `TeeSelectionView`, `RoundRowView`. |
| `ActiveRoundView.swift` | Full-screen round logging — hole picker, progress bar, mini scorecard, badge popup integration. |
| `HoleEntryView.swift` | Per-hole entry form — drive, approach, short game, putting, score. Submit triggers badge detection. |
| `StatsView.swift` | Stats tab — course/tee filters, overview card, charts, heat map, approach breakdown. |
| `StatsChartsView.swift` | Swift Charts components — `ScoringTrendChart`, `ScoreDistributionChart`, `PuttsTrendChart`, `HoleAvgChart`. |
| `SocialView.swift` | Social tab — friend list, friend codes, iCloud availability banner. |
| `CompareView.swift` | Head-to-head friend comparison — overall + per-hole + course-filtered. |
| `RoundDetailView.swift` | Completed round detail — score ring, sparkline, scorecard grid, expandable hole details. |
| `BadgePopupView.swift` | Animated badge overlay — spring animations, glow effects, auto-dismiss after 3 seconds. |
| `CourseListView.swift` | Course management — list, add via scorecard photo, set header photo. |
| `SettingsView.swift` | Settings — club bag editing, course management, data tools. |

### Theme.swift

Shared design tokens and utilities used across all views.

| Item | Purpose |
|------|---------|
| `AppTheme` | Static color palette (`fairwayGreen`, `gold`, `eagle`, `birdie`, `bogey`, etc.), gradients, corner radius. |
| `AnimatedNumber` | Animatable numeric display for smooth counting transitions. |
| `StaggeredAppear` | View modifier for cascading card entrance animations. |
| `ShimmerModifier` | Pulsing skeleton loading effect. |
| `Haptics` | Convenience wrappers for `UIImpactFeedbackGenerator`. |

## Data Flow

### Round Logging

```
User taps "New Round"
  → CoursePickerView (if multiple courses)
  → TeeSelectionView
  → Round + HoleScores created in SwiftData
  → ActiveRoundView presented (fullScreenCover)
    → HoleEntryView per hole
    → Submit button → BadgeManager.checkForBadges()
    → Badge popup if earned
  → Finish → unplayed holes deleted, round marked complete
  → CloudKit publish (if available)
```

### Badge Detection

```
HoleEntryView.onSubmit(score)
  → ActiveRoundView.submitCurrentHole(score)
    → BadgeManager.checkForBadges(score, allScores, index, round)
      → checkDoubleKill() — consecutive birdies
      → checkShaiHulud() — bunker + 1 putt
    → Session dedup via Set<String> prevents re-awards
    → pendingBadge published → onChange triggers BadgePopupView
    → Auto-advance to next hole
```

### Stats Computation

```
StatsView queries all completed rounds
  → Optional course filter → optional tee filter
  → StatsEngine.filtered(rounds:tee:)
    → Computes averages, distributions, per-hole stats
  → Charts and cards render from engine output
```

## Key Patterns

- **SwiftData `@Model`** for all persisted entities — automatic migration, live queries via `@Query`.
- **Singleton managers** (`BadgeManager.shared`, `CloudKitManager.shared`, `BagManager.shared`) for cross-cutting concerns persisted in UserDefaults.
- **`@Bindable`** for two-way binding to SwiftData models in forms (HoleEntryView).
- **`fullScreenCover(item:)`** for modal presentation with guaranteed non-nil binding.
- **Session-level dedup** in BadgeManager to prevent duplicate awards without relying on Date equality.
- **Lazy CloudKit** — container only initialized if iCloud entitlements are present. All methods guard on optional container.
