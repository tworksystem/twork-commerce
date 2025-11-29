# T-Work Points System Architecture

## High-Level Flow

```
┌────────┐      ┌─────────────────────┐      ┌──────────────────┐
│ Flutter│ ───► │ WordPress REST APIs │ ───► │ WooCommerce/DB   │
└────────┘      └─────────────────────┘      └──────────────────┘
     ▲                   │
     │                   ▼
┌────────────┐     ┌───────────────┐
│ Offline    │ ◄── │ Background/   │
│ Queue      │     │ Sync Handlers │
└────────────┘     └───────────────┘
```

- **Transactions** are cached locally, encrypted at rest, and replayed through the offline queue when connectivity resumes.
- **Point sync** uses exponential backoff, telemetry hooks, and toast notifications to surface failures to the customer.
- **WordPress plugin** records every transaction within a SQL transaction, writes structured logs with rotation, and exposes REST endpoints secured by WooCommerce API keys plus nonce verification for authenticated sessions.

## REST Endpoints

| Method | Route | Notes |
| ------ | ----- | ----- |
| `GET`  | `/twork/v1/points/balance/<user_id>` | Returns current totals; requires Woo credentials + nonce for cookies. |
| `GET`  | `/twork/v1/points/transactions/<user_id>` | Supports pagination, search, and filtered export. |
| `POST` | `/twork/v1/points/earn` | Creates earn/referral transactions; duplicate detection per user/order/type. |
| `POST` | `/twork/v1/points/redeem` | Deducts points; writes audit history when triggered from admin. |
| `POST` | `/twork/v1/points/sync` | Bulk sync for mobile offline queues. |

## Data Model

`wp_twork_point_transactions`

- `user_id`, `type`, `points`, `order_id`, `expires_at`, `is_expired`
- Unique constraint `(user_id, order_id, type)` prevents double credits on the same order.
- Indexed for expiration sweeps and history lookups.

`wp_twork_point_audit_log`

- Tracks admin adjustments with actor ID, delta, and reason for governance.

## Offline Queue

- Each point transaction is given a deterministic queue id (`point-<transaction_id>`).
- The queue deduplicates by id and replays items through `PointService.syncQueuedPointTransaction`.
- Failures remain in the queue until a retry succeeds or hits the retry ceiling, at which point they are logged and surfaced via telemetry.

## Logging & Monitoring

- Flutter logging goes through a shared `Logger` that emits `LogEvent`s to registered sinks (Crashlytics, alerts, analytics).
- Point sync telemetry publishes success/failure events, updates counters, and triggers toast + push notifications when backoff exhausts.
- WordPress plugin logs to `wp-content/uploads/twork-points-logs/twork-points.log` with 1 MB rotation, structured metadata, and admin notices when failures exceed a 1‑hour threshold.

## Deployment & CI

- GitHub Actions workflow (`.github/workflows/ci.yml`) runs `flutter format`, `flutter analyze`, `flutter test`, and PHP syntax checks.
- Plugin migrations add required indexes and audit table automatically via `dbDelta`.

## Seeding & Fixtures

`tools/seed_points.php` (see repo) populates base tier settings and sample transactions for staging environments. Run via WP-CLI:

```bash
wp eval-file tools/seed_points.php
```

This script is idempotent and safe to run multiple times.

