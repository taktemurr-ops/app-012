# Release acceptance gates
- [ ] `flutter analyze` clean on pinned Flutter SDK
- [ ] All `flutter test` suites green
- [ ] Android debug APK build, signed AAB, emulator and physical device verification
- [ ] iOS build, signing, simulator and physical device verification on macOS
- [ ] Verify encrypted persistence across restart, delete, migration and corrupted backups
- [ ] Arabic RTL and Turkish decimal accessibility checks
- [ ] Store privacy declarations, screenshots, privacy URL and app signing
- [ ] No live financial/payment APIs or monetization configured; do not claim otherwise

Do not mark the app as final until every required gate has been verified.
