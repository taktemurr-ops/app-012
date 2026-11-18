# APP-012 Borç 360 / Debt 360

Offline-first Flutter Android/iOS debt manager. Debt and receivable accounts, partial payments, payment history/undo, due dates, overdue dashboard, per-currency totals, fixed-rate installment estimator, encrypted local storage, full deletion and JSON backup import/export. Turkish, English and Arabic interfaces with RTL.

## Data model and limits
- Amounts are signed 64-bit integer minor units, never binary floating point for balances.
- Debt principal is never negative; repayments cannot exceed outstanding principal.
- Currency totals are deliberately **not** added across currencies without an FX rate.
- The installment planner is an estimate, not a bank quotation, and excludes fees and day-count interest.
- JSON backup is plain text **outside** encrypted storage. Users must safeguard shared backups.

## Run
```sh
flutter create --platforms=android,ios --project-name borc_360 .
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

## Release gate
Not production-approved until Flutter tests, Android/iOS builds, accessibility, encryption on real devices, privacy review, and signing are verified. No live banking, payment processing, ads or IAP are claimed.
