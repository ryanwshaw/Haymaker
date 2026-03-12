# CourseIQ — Product Spec

<!-- last-verified: 2026-03-12 -->

## Vision

CourseIQ is the golf tracking app for players who want real insight into their game — not just a scorecard, but a data-driven breakdown of every part of their round. Combined with a fun, Halo-inspired badge system and social features, it turns casual tracking into an engaging experience.

## Target Audience

- Recreational golfers who play 1-4 times per month
- Small communities of 10-50 golfers who want to compare stats
- Data-minded players who want more than just a total score

## Core Features

### 1. Round Tracking (Implemented)

Log rounds hole-by-hole with rich shot data:

- **Drive:** Club used, result (fairway, rough L/R, bunker, native, drop)
- **Approach (par 4/5):** Distance (10-yard buckets), club used, result (green, short/long/left/right, bunker)
- **Short Game (par 4/5):** Club used to get on green (when approach misses)
- **Putting:** Number of putts, 1st putt distance
- **Score & Penalties:** Adjustable score, penalty count

**Flow:** Course picker → Tee selector → Hole-by-hole entry with submit button → Finish round

**Partial rounds:** Submit after any number of holes. Unplayed holes are deleted. Scoring averages only tracked for exactly 9 or 18 holes.

### 2. Analytics (Implemented)

Stats across all courses or filtered to a single course + tee combination:

- **Overview:** Average 18/front-9/back-9 scores, best 18, fairway %, GIR %, putts/round, drops/round, average approach distance
- **Charts:** Scoring trend (line), score distribution (donut), putts per round (bar), per-hole average vs par (bar)
- **Heat Map:** Per-hole average scores, outliers highlighted, click-through to hole detail
- **Approach by Distance:** GIR % grouped by approach distance buckets

### 3. Badge System (In Progress)

Halo-inspired achievements earned during round logging:

- Pop up in real-time with animated overlay (spring animation, glow, 3-second display)
- Persisted in UserDefaults, aggregated per user
- Session-level dedup prevents re-awards within a round
- See `BADGES.md` for full list of planned badges

**Implemented:** Double Kill (2 birdies in a row), SHAI-HULUD (up-and-down from greenside bunker)

### 4. Social (Partially Implemented)

- **Local friends:** Add sample friend data, compare stats head-to-head
- **CloudKit friends (requires paid dev account):** Friend codes, friend requests, shared rounds
- **Compare view:** Overall stats side-by-side, per-hole breakdown when filtered by course

### 5. Course Management (Implemented)

- Default course (Haymaker) seeded with full hole data and tee info
- Add courses via scorecard photo (Vision OCR)
- Set course header photo for visual identity
- Multiple tee configurations per course

## Roadmap

### Near Term
- [ ] Implement remaining badge types from `BADGES.md`
- [ ] Badge gallery / profile view showing all earned badges
- [ ] Badge comparison with friends

### Medium Term
- [ ] Driving distance tracking per hole
- [ ] Scrambling % and sand save % stats
- [ ] Round notes / per-hole notes
- [ ] Export round data (CSV, shareable image)

### Long Term
- [ ] Apple Watch companion for quick score entry
- [ ] Club recommendation engine based on approach data
- [ ] Push notifications for friend round completions
- [ ] Paid Apple Developer account for TestFlight + CloudKit
