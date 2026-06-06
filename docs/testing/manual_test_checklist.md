Manual Test Checklist — Multi-College SaaS Upgrade
Run all scenarios on a PHYSICAL device before every release.
Check each box only after observing the expected result yourself.

Pre-requisites

- [ ] A debug APK is installed: flutter run --dart-define=COLLEGE_ID=kec
- [ ] Firebase Realtime Database has at least 1 student under /colleges/kec/studentsByRoll/
- [ ] Admin portal is running locally: cd admin_portal && npm run dev
- [ ] Device has a working internet connection (Wi-Fi preferred)

Scenario 1 — First Install · No Server Data
Setup: Clear app data (Settings → Apps → Clear Data) OR fresh emulator
Server state: /colleges/kec/studentsByRoll/ is EMPTY
Steps:

- [ ] Open the app
- [ ] Expected: BlockedScreen appears immediately
- [ ] Expected: College name from config.json is shown on BlockedScreen
- [ ] Expected: "Retry Sync" button is visible
- [ ] Tap "Retry Sync"
- [ ] Expected: Spinner shows, then BlockedScreen remains (still no data)
- [ ] No crash, no unhandled exception in Crashlytics

Scenario 2 — First Install · Data Exists on Server
Setup: Clear app data. Server has students loaded.
Steps:

- [ ] Open the app
- [ ] Expected: Home screen loads (no BlockedScreen)
- [ ] Tap the Sync button (AppBar / FAB)
- [ ] Expected: SyncProgressSheet appears showing steps in order: checking → downloading → applying → done
- [ ] Expected: Green snackbar: "Synced to v{X} · {N} records updated"
- [ ] Expected: localVersion in SharedPreferences equals server version
- [ ] Create a test event and scan a roll number
- [ ] Expected: Attendee appears in timeline (green row) — no Firebase call

Scenario 3 — Already Up To Date (NO_OP)
Setup: Scenario 2 completed. Do NOT change anything on server.
Steps:

- [ ] Tap Sync button again
- [ ] Expected: No SyncProgressSheet opens
- [ ] Expected: No snackbar or a quiet "Already up to date" info snackbar
- [ ] Expected: No Hive data was cleared or rewritten

Scenario 4 — Incremental Sync (small patch gap ≤ 3)
Setup: Scenario 2 completed. localVersion is e.g. "1.3"
Steps:

- [ ] In the admin portal, make a small change (rename one student) and press Save
- [ ] Expected: Server version bumps to "1.4" (check header in portal)
- [ ] Back on device, tap Sync
- [ ] Expected: SyncProgressSheet shows: checking → comparing → applying → done
- [ ] Expected: Only the changed record is updated in Hive (not a full wipe)
- [ ] Expected: localVersion in prefs is now "1.4"

Scenario 5 — Offline Scan (OfflineLookupMiss)
Setup: Scenario 2 completed. Enable Airplane Mode on device.
Steps:

- [ ] Open an existing event
- [ ] Scan a roll number that is NOT in the local Hive students cache
- [ ] Expected: Grey timeline row · label "Not in cache" · cloud-off icon
- [ ] Expected: No crash, no spinner freeze
- [ ] Scan a roll number that IS in Hive cache
- [ ] Expected: Normal green entry row — works offline
- [ ] Tap Sync button while offline
- [ ] Expected: Snackbar: "Offline — using cached data (v{version})"

Scenario 6 — Scan Error Rows (all types)
Setup: Airplane Mode OFF. Event open. Scanner active.
Steps:

- [ ] Scan a completely invalid barcode (e.g. "XXXXXX")
- [ ] Expected: RED row · "Invalid code" · x-circle icon

- [ ] Scan a correctly formatted but unknown roll number
- [ ] Expected: ORANGE row · "Unknown student" · question icon

- [ ] Scan a valid student twice quickly (within cooldown window)
- [ ] Expected: YELLOW row · "Wait {N}s" · clock icon

- [ ] Scan exit for a student who never entered
- [ ] Expected: YELLOW row · "Already exited" · warning icon

Scenario 7 — Version Rollback (Admin Portal)
Setup: At least 3 saved versions exist in Firebase.
Steps:

- [ ] Open admin portal → click Version History (drawer)
- [ ] Expected: Versions listed newest-first with timestamp + updatedBy
- [ ] Click "Rollback to this version" on an older version
- [ ] Expected: Rollback button becomes disabled during rollback
- [ ] Expected: Header version updates in real-time after rollback
- [ ] Expected: New version entry in history with changeSummary = "Rollback to v{X}"
- [ ] On device, tap Sync
- [ ] Expected: Full or incremental sync pulls rolled-back student data

Scenario 8 — Incremental Fail → Full Sync Fallback
Setup: Manually set syncIncrementalFailCount = 2 in SharedPreferences using a debug screen or Flutter DevTools.
Steps:

- [ ] Trigger any sync
- [ ] Expected: Full sync runs (not incremental) regardless of gap size
- [ ] Expected: On success, syncIncrementalFailCount resets to 0

Sign-Off

| Scenario | Tester | Date | Pass/Fail | Notes |
|---|---|---|---|---|
| 1 — No server data |  |  |  |  |
| 2 — First install |  |  |  |  |
| 3 — NO_OP |  |  |  |  |
| 4 — Incremental sync |  |  |  |  |
| 5 — Offline scan |  |  |  |  |
| 6 — Scan error rows |  |  |  |  |
| 7 — Version rollback |  |  |  |  |
| 8 — Fail fallback |  |  |  |  |

Release gate: ALL scenarios must be Pass before building release APK.
