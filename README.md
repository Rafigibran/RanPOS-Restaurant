# RanPOS

Offline-first restaurant point of sale, built with Flutter for Android.
Android application ID: `com.rafdevplay.ranpos`

Design direction follows the reference screenshots Rafi supplied
(light background, white cards, coral-red primary action, centre
create button, floor tabs, menu list with price steppers, order
detail with tax and total), rebuilt with original code, original
demo content and the RanPOS name. No brand, dish name or person
from the reference is copied.

## What works in MVP

- Onboarding and business setup (name, currency, tax %). The app starts
  completely empty: no demo menu, floors, tables or orders are ever
  created. No internet or cloud account needed.
- Dashboard: revenue from paid payments only, in-progress count,
  waiting-payment count, popular dishes, out-of-stock and low-stock,
  recent transactions.
- Orders: search and filters (all, in progress, ready, waiting payment,
  completed, cancelled), order detail, status transitions, payment
  recording (cash / card-transfer as manual recording), change for cash.
- Create order: dine-in / takeaway, customer or walk-in, guests,
  available-table guard (one active order per table), menu with
  quantity steppers, subtotal / tax / total, atomic save.
- Tables: floors and tables are added, edited and deleted by the user
  from the Tables tab, with an available / occupied legend.
- Menu and categories, customers, simple stock with movement history
  and return-to-stock on cancellation.
- In-app notifications for order created, order ready and payment.
- Reports: today / week / month / all, revenue, order count, average,
  top items, payment methods, CSV export to the app documents folder.
- 6 languages: Indonesian, English, Japanese, Simplified Chinese,
  Spanish, Arabic (RTL). Device locale on first launch, English
  fallback, manual choice in Settings, persisted.
- Local backup / restore as a JSON snapshot with schema version
  validation. Cloud backup is optional and uses the user's own
  Supabase project (see docs/supabase-setup.md).

## Money and data rules

- Money is stored as integers in the smallest unit, never float.
- Order items snapshot name and price, so later menu edits do not
  change old transactions.
- Order status and payment status are separate fields.
- Stock is reduced when an order is confirmed and returned when
  an order is cancelled, with a recorded movement each time.

## Run and test

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build web --release
flutter build apk --release
```

Local Android builds need an Android SDK; the GitHub Actions
workflow in `docs/workflows/flutter-ci.yml` builds the APK in CI.

## Build with GitHub Actions

The GitHub connector cannot write `.github/workflows/` files and
cannot push binary template assets. So:

1. Push this source to `Rafigibran/RanPOS-Restaurant` (main).
2. In the GitHub web UI, create `.github/workflows/flutter-ci.yml`
   and paste the exact contents of `docs/workflows/flutter-ci.yml`.
3. Push or re-run the workflow. Download `ranpos-apk` from the
   run's Artifacts section.

The workflow regenerates missing template binary assets
(gradle-wrapper.jar, launcher icons, web icons) from the installed
Flutter template before building, so only missing files are copied.

## Known limits (MVP, honest)

- Supabase backup is backup / restore, not realtime multi-device sync.
- No thermal printer, barcode scanner, payment gateway, payroll or
  multi-branch support. Those are Phase 2 in the PRD.
- Staff roles are single-user Admin in this MVP; role permissions
  are a Phase 2 item.
- The CSV export in Reports currently exports payment-method totals;
  full transaction export is a follow-up, not claimed as complete.
- On-device APK install, end-to-end Supabase backup against a real
  project, and RTL layout on a real Arabic device are still to be
  verified by the owner after CI goes green.
- Release APK from CI is debug-signed by the Flutter template config:
  fine for sideload testing, not for Play Store (needs a real keystore).
