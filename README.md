# QR Scanner Attendance System

A QR-based attendance platform with a Flutter mobile app and a React admin portal.

## Application Features

### Mobile App (Flutter)
- QR code scanning for attendance check-in/check-out
- Event-based attendance sessions with entry/exit scan modes
- Cooldown protection to prevent rapid duplicate scans
- Offline-first local storage using Hive
- Student profile lookup with local cache and remote fallback
- Attendance export to Excel
- Department mapping management
- Local analytics counters for scan outcomes and exports
- Anonymous Firebase auth support for app bootstrap

### Admin Portal (React + Firebase)
- Email/password admin login with custom admin-claim access
- Spreadsheet-style student data editing
- Hierarchy-based student navigation (Department → Year → Section)
- Bulk import from CSV/Excel and paste input
- Undo/redo support for row edits
- Batch save with hierarchical index synchronization
- Append-only audit logging for create/update/delete student mutations

### Security & Reliability
- Realtime Database least-privilege access (admin-only student/hierarchy data)
- Append-only audit branch for student mutations with before/after snapshots
- Structured application logging
- Crash reporting integration via Firebase Crashlytics
- Retry/backoff strategy for RTDB student lookups

## Run Commands

### 1) Mobile App
```bash
flutter pub get
flutter run
```

### 2) Admin Portal
```bash
cd admin_portal
npm install
npm run dev
```

## Build Commands

### Android APK (Release)
```bash
flutter build apk --release
```

### Android App Bundle (Play Store)
```bash
flutter build appbundle --release
```

### Admin Production Build
```bash
cd admin_portal
npm run build
```

### Admin Deploy (Firebase Hosting)
```bash
cd admin_portal
firebase deploy --only hosting
```
