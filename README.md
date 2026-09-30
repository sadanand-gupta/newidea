# KryptoX: crypto market intelligence app

KryptoX is a CoinGecko-style crypto research app. The app is written in Flutter/Dart and the backend in Node.js with Express.

| Part | Stack | Packages |
|------|-------|----------|
| `flutter_app/` | Flutter 3.38+ | `flutter_animate`, `animations`, `fl_chart`, `google_fonts`, `cached_network_image`, `provider`, `http` |
| `backend/` | Node.js 18+ | `express` (uses the built-in `fetch` and `crypto`) |

```
Flutter app  ──HTTP/JSON──▶  Node backend (:8080)  ──▶  CoinGecko public API
                                   │  60s cache, stale-cache and demo-data fallback
                                   └─ watchlist.json (persisted watchlist)
```

## Design

- **Visual style:** a dark theme with cyan→violet neon highlights and frosted-glass panels.
  - The background has drifting glows over a faint moving grid.
  - Fonts: Space Grotesk for headings, Inter for text, and JetBrains Mono for all numbers so prices line up.
- **Motion:**
  - A splash screen where the logo ring sweeps in and the "X" draws itself.
  - A floating glass nav bar with a sliding glow, and haptic feedback on taps.
  - List rows and sections animate in one after another, and loading placeholders shimmer.
  - Prices roll to their new value and flash green or red when they change.
  - Charts and sparklines draw themselves in, and the coin logo flies from the list into the detail page.
  - A scrolling price ticker along the top of Markets, and a pulsing LIVE / CACHED / DEMO badge showing where the data came from.

## Screens

The app has no sign-in. A bottom bar switches between Home, Markets, Stats and Watchlist, and the side menu offers the same tabs plus an About dialog.

- **Home** (opens first)
  - A global market card: total market cap, 24h change, volume, BTC dominance and coin count.
  - Top 5 gainers or losers, and a preview of your watchlist, each with a "See all" link to its tab.
- **Markets**
  - The price ticker, and a Trending carousel of the biggest 24h movers.
  - Search and filter chips (All / Top 10 / Gainers / Losers / Stablecoins) stay pinned while you scroll. Search is debounced and runs on the server.
  - A sort sheet (market cap, price, volume, 24h or 7d change, name; ascending or descending).
  - Prices refresh every 30 seconds, pausing when the app is in the background, and you can pull to refresh.
- **Coin details**
  - An interactive chart for 24H, 7D, 30D, 90D and 1Y. Drag across it and the big price shows the historical price, date and change at that point.
  - A 24h range bar, performance tiles, and market stats including all-time high and low.
  - An animated supply progress bar and an expandable About section.
- **Stats:** a global market dashboard.
  - A market cap summary card and KPI tiles whose numbers count up.
  - An animated dominance donut chart you can tap.
  - A sentiment gauge. It is an estimate calculated in the app, not an official index.
  - A Gainers / Losers / Volume switcher.
- **Watchlist**
  - A summary: number of coins, average 24h change, best and worst performer, and a strip showing each coin's move.
  - Sort chips, swipe to remove with undo. The list is saved on the backend.
- **Every screen** has loading, error and empty states. If a refresh fails, the old data stays visible with an error banner.
- **Every layout** works from 320px phones to wide desktop windows (content is centred with a maximum width) and with large system text. Buttons have 44px tap targets and screen-reader labels.
- Hidden tabs and a backgrounded app stop polling for new prices.

## Run it (on a machine with Flutter 3.38+ and Node.js 18+)

**1. Backend**
```powershell
cd backend
npm install
npm start                         # live CoinGecko data, falls back automatically
# $env:USE_MOCK="1"; npm start    # demo data, no network needed
```
Test it at http://localhost:8080/api/coins?search=bit&sort=price.

The free CoinGecko API is rate-limited to about 30 calls a minute. When the limit is hit, the backend serves cached data, and falls back to demo data if nothing is cached. You can set `COINGECKO_API_KEY` to a free demo key for higher limits.

**2. App** (in a second terminal)
```powershell
cd flutter_app
.\setup.ps1          # once: generates android/ios/web/windows folders, enables HTTP on Android
flutter run          # pick an Android emulator, Chrome or Windows
flutter test         # unit tests
```

- The Android emulator reaches the backend at `10.0.2.2:8080` automatically.
- For a real phone on the same Wi-Fi, run:
  `flutter run --dart-define=API_BASE_URL=http://<your-PC-IP>:8080`

## API

| Method | Path | Notes |
|--------|------|-------|
| GET | `/api/coins?search=&filter=all\|top10\|gainers\|losers\|stablecoins&sort=market_cap\|price\|volume\|change_24h\|change_7d\|name&order=desc\|asc` | Coin list |
| GET | `/api/coins/{id}` | Coin details |
| GET | `/api/coins/{id}/chart?days=1\|7\|30\|90\|365` | Price history as `[[ms, price], ...]` |
| GET | `/api/global` | Market stats plus top gainers, losers and volume |
| GET | `/api/watchlist` · `/api/watchlist/ids` | Watchlist coins or ids |
| POST / DELETE | `/api/watchlist/{id}` | Add or remove a coin |
| POST | `/api/auth/signup` · `/api/auth/login` | Body `{ "username", "password", "email"? }`, returns `{ user, token }` |
| GET / POST | `/api/auth/profile` · `/api/auth/logout` | Needs `Authorization: Bearer <token>` |

Every data response has the shape `{ "source": "live|cache|mock", "updated_at": <unix>, "data": ... }`.

## Project layout

```
flutter_app/lib/
  main.dart                 providers, theme, splash → shell
  theme/app_theme.dart      design tokens (colours, fonts, page transitions)
  models/ services/ state/  data models, API client, Loadable + WatchlistProvider
  widgets/                  design system: glass, background, animated price,
                            chart, sparkline, controls, nav bar, state views
  screens/                  splash, shell, home, markets, detail, stats, watchlist
backend/
  src/server.js             Express routes, filtering/sorting, watchlist, auth API
  src/coingecko.js          upstream client, cache, normalisation
  src/mockData.js           offline demo data
  src/userStore.js          users (users.json), password hashing, tokens
```
