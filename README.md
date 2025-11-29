# T‑Work Commerce

Modern Flutter commerce experience powered by WooCommerce + WordPress.  
Single codebase targets iOS, Android, Web, Desktop and ships with an enterprise-ready loyalty program, offline queue, monitoring hooks, and CI assets.

---

## Feature Highlights
- **Multi-channel storefront** – Weekly curated hero, animated product detail, deep search/filter with bottom sheet UX.
- **WooCommerce integration** – Orders, carts, checkout, and catalog pulled from WordPress REST with retry policies, lightweight caching, and offline fallbacks.
- **Points & loyalty** – Native points provider, offline queue, and WordPress plugin (`docs/POINTS_ARCHITECTURE.md`, `README_POINTS_SYSTEM.md`) covering earn/redeem/sync endpoints.
- **Wallet & payments** – P2P send/request money flows, voucher rails, checkout cards, and dynamic payment summaries.
- **Notifications & background services** – Push/local notification abstractions, WorkManager order polling, and in-app notification center.
- **Ops toolbelt** – Logger sinks, monitoring dashboard widget, retry manager, seed scripts, CI workflows, and Flutter/Dart integration tests.

---

## Architecture Overview
| Layer | Description |
| --- | --- |
| **Flutter UI** | Modular screens under `lib/screens/**` with Provider for state, shared widgets, and hero animations. |
| **Domain Models** | `lib/models/**` contains WooCommerce DTOs, cart items, loyalty transactions, and auth payloads. |
| **Services** | `lib/services/**` handles networking, auth, points, offline queue, notifications, secure storage, and logging. |
| **Backend** | WordPress/WooCommerce plugin (`wp-content/plugins/twork-points-system`) exposes REST endpoints for points, orders, and audit logging. |

---

## Getting Started
### Prerequisites
- Flutter 3.24+ (`flutter doctor` clean)
- Dart 3.3+
- Android Studio / Xcode command-line tools
- WooCommerce + WordPress backend (API keys configured in `lib/utils/app_config.dart`)

### Install & Run
```bash
flutter pub get
flutter gen-l10n
flutter run            # defaults to your connected device
```

For web/desktop targets, enable the platform (`flutter config --enable-web`, etc.) and run `flutter run -d chrome` or `flutter run -d macos`.

### Environment
- **App configuration**: `lib/utils/app_config.dart`
- **Secrets**: supply WooCommerce keys + backend URL via `SecurePrefs`/`SharedPreferences`.
- **Push/analytics**: update `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, or equivalent for your provider.

---

## Project Structure (excerpt)
```
lib/
 ├─ screens/                # Feature screens (auth, main, product, wallet, etc.)
 ├─ services/               # Network, loyalty, notifications, offline queue, secure prefs
 ├─ providers/              # State management (cart, points, orders, auth, ...)
 ├─ models/                 # Data contracts for WooCommerce + app domain
 ├─ widgets/                # Reusable UI components (badges, cards, monitoring)
 └─ utils/                  # Logger, error handling, tests, monitoring helpers
docs/
 └─ POINTS_ARCHITECTURE.md  # Loyalty system flow, REST routes, data model
wp-content/
 └─ plugins/twork-points-system/   # WordPress plugin powering points API
```

---

## Quality & Tooling
- `analysis_options.yaml` enforces lint + formatting.
- `test/**` includes widget/service tests; run `flutter test`.
- CI workflows (under `.github/`) cover format, analyze, test, PHP syntax for the plugin.

---

## Contributing
1. Fork & create a feature branch.
2. Keep commits scoped (UI/service/plugin changes isolated).
3. Run `flutter format`, `flutter analyze`, and `flutter test` before opening a PR.

---

## License
MIT – see `LICENSE` for details. Extras (assets, fonts) remain copyright of their respective owners.
