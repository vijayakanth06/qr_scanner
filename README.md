# QR Scanner Attendance System

Release-ready QR attendance platform with:
- a Flutter mobile app for live event scanning and attendance capture
- a React admin portal for student master-data management
- Firebase Realtime Database for secured student and hierarchy data
- local-first attendance persistence for operational reliability during events

## What V2 Includes

### Mobile App (Flutter)
- Event creation with venue, scan mode, cooldown, and duplicate-exit policy
- QR/barcode scanning with live feedback, haptics, and recent-result timeline
- Entry/exit attendance handling through `AttendanceFlowService`
- Local-first attendance persistence using Hive
- Firebase bootstrap with anonymous auth when available
- Firebase Crashlytics wiring for runtime error reporting
- RTDB student lookup with retry/backoff fallback flow
- Department mapping and export folder settings
- Excel export with selectable columns

### Admin Portal (React + Firebase)
- Email/password login
- Custom admin-claim gate before data access
- Hierarchy-based student browsing: Department -> Year -> Section
- Spreadsheet-style inline editing
- CSV/XLSX import and paste-based bulk entry
- Undo/redo editing workflow
- Batched RTDB writes to:
  - `studentsByRoll`
  - `hierarchy`
  - `audit/studentMutations`
- Append-only audit entries for create/update/delete changes

## Current Release Flow

### Mobile attendance flow
1. App bootstraps Firebase, Crashlytics, Hive, and DI.
2. Staff creates or opens an event from the home screen.
3. Event screen launches barcode scanning.
4. Scanned QR is normalized and checked against cooldown rules.
5. Student profile is resolved from in-memory cache, then RTDB fallback if needed.
6. User confirms Entry or Exit when event mode is `both`.
7. `AttendanceFlowService` validates business rules and records attendance in Hive.
8. UI updates the attendee list and scan timeline.
9. Attendance can be exported to Excel from the event screen.

### Admin data flow
1. Admin signs in with Firebase Auth.
2. Portal verifies custom admin claim.
3. Portal loads hierarchy and section records from RTDB.
4. Admin edits rows inline or imports data from CSV/XLSX/paste.
5. Save builds a single multi-path RTDB update for student data, hierarchy paths, and audit entries.

## Architecture Summary

### Flutter app
- `lib/app/bootstrap.dart`: startup, Firebase init, Crashlytics, Hive, DI
- `lib/app/di.dart`: GetIt registrations
- `lib/core/config/`: environment configuration
- `lib/core/logging/`: structured logging
- `lib/features/events/`: event creation and navigation
- `lib/features/attendance/`: scanning, policies, attendance recording, export
- `lib/features/settings/`: department and export location management
- `lib/features/students/`: RTDB-backed student profile lookup and import use case

### Data and storage
- Hive stores events and attendees on-device
- SharedPreferences stores settings such as department mapping and export location
- Firebase Realtime Database stores:
  - `studentsByRoll`
  - `hierarchy`
  - `audit/studentMutations`

## Security and Reliability

- RTDB root access denied by default
- Student, hierarchy, and audit branches require admin claim access
- Audit writes are append-only
- Mobile app continues offline if Firebase bootstrap is unavailable
- Crashlytics is configured during bootstrap
- RTDB student lookup uses bounded retry/backoff

## Docs and Diagrams

Release diagrams live in:
- `docs/diagrams/flowchart-diagram.mmd`
- `docs/diagrams/orchestration-diagram-pipeline.mmd`
- `docs/diagrams/sequence-diagram.mmd`

These diagrams now reflect the implemented V2 flow rather than the earlier draft architecture.

## Run Commands

### Mobile App
```bash
flutter pub get
flutter run
```

### Admin Portal
```bash
cd admin_portal
npm install
npm run dev
```

## Test Commands

```bash
flutter analyze
flutter test
flutter test integration_test
```

## Build Commands

### Android APK (Release)
```bash
flutter build apk --release
```

### Android App Bundle (Release)
```bash
flutter build appbundle --release
```

### Admin Production Build
```bash
cd admin_portal
npm run build
```

### Admin Deploy
```bash
cd admin_portal
firebase deploy --only hosting,database
```

## Optional Dart Defines

```bash
flutter run \
  --dart-define=APP_ENV=production \
  --dart-define=FIREBASE_DATABASE_URL=https://your-project-default-rtdb.asia-southeast1.firebasedatabase.app \
  --dart-define=ENABLE_DIAGNOSTICS=false
```
