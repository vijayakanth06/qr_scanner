# QR Event Attendance Platform

Offline-first QR/barcode attendance system for college events, built with a Flutter scanner app, a React admin portal, and Firebase Realtime Database. It replaces paper registers and ad‑hoc spreadsheets with a reliable, auditable workflow for creating events, scanning students at entry/exit, and exporting clean attendance data.

> [!NOTE]
> This README is the extended project overview you can use for viva / reports. It explains the objective, architecture, data model, flows, and how to run both apps.

---

## 1. Overview

The platform consists of two cooperating applications:

- **Mobile Scanner App (Flutter)** – used by staff at the venue to:
  - Create events with scan policies (entry/exit mode, cooldown, duplicate-exit restriction).
  - Scan QR/barcodes printed on student ID cards.
  - Record entry and exit times even when offline, using local storage.
  - Export attendance as Excel for reporting.

- **Admin Portal (React + Firebase)** – used by admins to:
  - Manage the student master database in a spreadsheet-like UI.
  - Organize students by Department → Year → Section.
  - Import/update records from Excel/CSV or pasted data.
  - Maintain an audit log of every change for traceability.

Core design goals:

- Fast scanning with immediate visual feedback.
- Works reliably in low‑network or offline environments.
- Clean, normalized student data shared across all events.
- Strong separation between **admin** operations and **scanner** operations.

---

## 2. Technology Stack

**Frontend / Apps**
- Flutter (Dart) – cross‑platform mobile/desktop/web scanner app.
- React + Vite – admin portal web app.

**Backend / Services**
- Firebase Authentication – email/password + admin claim (portal), anonymous auth (scanner).
- Firebase Realtime Database – canonical store for:
  - `studentsByRoll` (student master data).
  - `hierarchy` (department/year/section → roll numbers).
  - `audit/studentMutations` (immutable audit log).
- Firebase Crashlytics – error reporting from the Flutter app.

**Local Storage (Scanner)**
- Hive – embedded key/value database:
  - `events` box – event metadata and scan policy.
  - `attendees` box – per‑scan attendance records.
- Shared preferences (via settings service) – export path and departments config.

**Tooling**
- GetIt – dependency injection container for Flutter services.
- npm / Node – admin portal build and dev tooling.

---

## 3. High‑Level Architecture

At a high level the system looks like this:

- **Admin Portal → Firebase RTDB**
  - Admin signs in with email/password.
  - Portal verifies `admin` custom claim.
  - Students are managed under `studentsByRoll/{ROLL_NO}`.
  - Hierarchy indices live under `hierarchy/{BRANCH}/{YEAR}/{SECTION}/{ROLL_NO}`.
  - Every change generates an audit entry in `audit/studentMutations/{ENTRY_ID}`.

- **Scanner App → Hive + Firebase RTDB**
  - App bootstraps Firebase and signs in anonymously (best effort).
  - Local boxes `events` and `attendees` are opened via Hive.
  - For each scan, the app:
    - Normalizes the scanned value to a roll number.
    - Optionally looks up the student profile via `studentsByRoll/{ROLL_NO}`.
    - Uses `AttendanceFlowService` to decide entry vs exit and validate rules.
    - Persists the result to the local `attendees` box.
  - Attendance can be exported to Excel from the event screen.

This design allows **admin operations** to stay online and structured, while **scanning operations** stay lightweight and resilient in the field.

---

## 4. Project Structure

Top‑level layout (simplified):

```text
qr_scanner/
  lib/                 # Flutter app source
    app/               # bootstrap + DI + root widget
    core/              # config, logging
    features/
      attendance/      # scanning, attendance flow, export
      events/          # event list + creation
      students/        # RTDB-backed student repository
      settings/        # departments + export folder config
  admin_portal/        # React + Vite admin portal
  docs/diagrams/       # architecture and flow diagrams (Mermaid)
  android/, ios/, web/ # Flutter platform builds
```

Key Flutter files:

- `lib/main.dart` – entry point, calls `bootstrap()`.
- `lib/app/bootstrap.dart` – initializes Firebase, Crashlytics, Hive, DI, and runs `QrScannerApp`.
- `lib/app/di.dart` – registers `FirebaseAuth`, `FirebaseDatabase`, repositories, and `AttendanceFlowService` via GetIt.
- `lib/features/events/presentation/screens/home_screen.dart` – event list, creation, deletion.
- `lib/features/attendance/presentation/screens/event_screen.dart` – event detail + scan workflow, Excel export.
- `lib/features/attendance/presentation/screens/barcode_scanner_screen.dart` – camera scanner UI.
- `lib/features/students/data/firebase_student_repository.dart` – reads `studentsByRoll/{ROLL_NO}` with retry/backoff.

Key admin portal files:

- `admin_portal/src/firebase.js` – Firebase app initialization; exports `auth` and `db`.
- `admin_portal/src/App.jsx` – login, admin-claim enforcement, hierarchy tree, spreadsheet editor, Excel import/export, audit writes.
- `admin_portal/src/styles.css` – layout + grid styling.

---

## 5. Data Model

### 5.1 Firebase Realtime Database

- **studentsByRoll/{ROLL_NO}**
  - `rollNo`: string, e.g. `23ALR109`.
  - `name`: student name.
  - `studentMobileNo`: contact number.
  - `branch`: department/branch code (e.g. `AIML`).
  - `yearOfStudy`: `I`, `II`, `III`, or `IV`.
  - `section`: section letter (e.g. `A`).
  - `gender`, `hostellerDayScholar`, `parentMobileNo`: optional.
  - `updatedAt`, `updatedBy`, `_sourceRoll`: metadata.

- **hierarchy/{BRANCH}/{YEAR}/{SECTION}/{ROLL_NO}**
  - Value: `true` (membership flag).

- **audit/studentMutations/{ENTRY_ID}**
  - `action`: `create` | `update` | `delete`.
  - `rollNo`: affected roll.
  - `actorUid`, `actorEmail`: admin identity.
  - `timestamp`: Unix epoch ms.
  - `before`: old student object or `null`.
  - `after`: new student object or `null`.
  - `sourceRoll`, `sourcePath`: origin metadata (e.g. `admin_portal`).

### 5.2 Local Hive Boxes (Scanner)

- **events** (`Event` entity)
  - `name`, `venue`, `date`.
  - `scanMode`: `both`, `entryOnly`, or `exitOnly`.
  - `cooldownSeconds`: min interval before the same roll can be scanned again.
  - `restrictDuplicateExit`: prevents repeated exit without a new entry.

- **attendees** (`Attendee` entity)
  - `id`: roll number.
  - `eventName`.
  - `name`, `department`, `batch`, `yearOfStudy`.
  - `inTime`, `outTime`.

---

## 6. Core Features

### 6.1 Scanner App

- Event creation with scan mode + cooldown + duplicate‑exit policy.
- QR/barcode scanning with:
  - Haptics.
  - Cooldown enforcement per roll number.
  - Recent scan timeline with status (ENTRY, EXIT, BLOCKED, INVALID, INFO).
- Entry/exit logic encapsulated in `AttendanceFlowService` and `ScanPolicyService`.
- Student profile resolution via `FirebaseStudentRepository` with in‑memory caching.
- Offline‑first storage of all events and attendees in Hive.
- Excel export with configurable columns and user‑selected output folder.

### 6.2 Admin Portal

- Email/password login and admin‑claim restriction.
- Department hierarchy explorer: **Branch → Year → Section**.
- Spreadsheet‑style inline editor with:
  - Keyboard navigation (arrows, Tab, Enter).
  - Dirty cell highlighting.
  - Undo/redo stacks.
- Bulk import via:
  - CSV/XLSX using `xlsx`.
  - Paste from Excel/Sheets.
- Normalization and validation:
  - Column name cleanup.
  - Roll number, branch, year, section normalization.
  - Required‑field checks before save.
- Batched RTDB update for students, hierarchy paths, and audit entries.

---

## 7. Request and Scan Flows

### 7.1 Admin Data Flow

1. Admin signs in via Firebase Auth.
2. Portal verifies `auth.token.admin === true`.
3. `hierarchy` node is loaded to display department/year/section navigation.
4. When a section is selected, the portal:
   - Reads roll numbers from `hierarchy/{BRANCH}/{YEAR}/{SECTION}`.
   - Loads full profiles from `studentsByRoll/{ROLL_NO}`.
5. Admin edits records or imports new ones.
6. On Save, the portal builds a single multi‑path update to:
   - Upsert `studentsByRoll` entries.
   - Update `hierarchy` membership.
   - Append `audit/studentMutations` entries.

### 7.2 Event Attendance Flow

1. App calls `bootstrap()` to initialize Firebase, Crashlytics, Hive, and DI.
2. Staff opens or creates an event on the Home screen.
3. Event screen launches the barcode scanner.
4. Scan handler:
   - Normalizes the scanned value to uppercase roll (`23ALR109`).
   - Applies cooldown (`_lastScanByRoll`) to prevent rapid duplicates.
   - Resolves student profile from cache or `studentsByRoll` via RTDB.
   - Suggests an action (Entry/Exit) based on last active record and `scanMode`.
   - Calls `AttendanceFlowService.recordAttendance` to persist to Hive.
5. UI updates attendee list and compact scan timeline.
6. Operator can export attendance to Excel for the event.

---

## 8. Security & Permissions

> [!IMPORTANT]
> For exams and demos you may temporarily loosen rules, but production should restrict writes to admins only.

- RTDB root `.read` / `.write` is denied by default.
- For production, recommended patterns:
  - `studentsByRoll` and `hierarchy`:
    - `.read`: any authenticated user (scanner + portal).
    - `.write`: admins only (`auth.token.admin === true`).
  - `audit/studentMutations`:
    - append‑only; only admins can write new entries.
- Scanner app uses **anonymous auth**, so read rules must not require `admin`.
- Crashlytics is enabled in non‑debug mode to collect error reports.

---

## 9. Running the Apps

### 9.1 Prerequisites

- Flutter SDK installed and `flutter` on PATH.
- Node.js + npm for admin portal.
- Firebase project configured with:
  - Web app for admin portal.
  - Android/iOS/web config for Flutter (Google services files).
  - Realtime Database and Authentication enabled.

### 9.2 Scanner App (Flutter)

```bash
flutter pub get
flutter run
```

To target a specific device:

```bash
flutter devices
flutter run -d <device-id>
```

Optional Dart defines:

```bash
flutter run \
  --dart-define=APP_ENV=production \
  --dart-define=FIREBASE_DATABASE_URL=https://your-project-default-rtdb.asia-southeast1.firebasedatabase.app \
  --dart-define=ENABLE_DIAGNOSTICS=false
```

### 9.3 Admin Portal

```bash
cd admin_portal
npm install
npm run dev
```

Production build and deploy:

```bash
cd admin_portal
npm run build
firebase deploy --only hosting,database
```

---

## 10. Testing & Quality

### Flutter

```bash
flutter analyze
flutter test
flutter test integration_test
```

The most critical logic to test is in:

- `AttendanceFlowService` – entry/exit rules, duplicate handling, cooldown.
- `ScanPolicyService` – enforcement of `scanMode` and restrictions.
- Roll‑number parsing utilities – consistent interpretation of IDs.

### Admin Portal

- Key behaviors to validate manually or via tests:
  - Undo/redo correctness.
  - Validation of required fields before Save.
  - Correct audit entries for create/update/delete.

---

## 11. Troubleshooting (Exam‑Friendly)

- **Scanner shows `Unknown` name / `Year ?` after scanning**
  - Cause: scanner cannot read `studentsByRoll/{ROLL_NO}` or field names don’t match.
  - Fix:
    - Ensure database rules allow `.read` for `studentsByRoll` for authenticated (including anonymous) users.
    - Check that `studentsByRoll/23ALR109` contains `name` and `yearOfStudy` (exact keys).
    - Fully restart the Flutter app after changing Firebase rules.

- **Scanner app fails to start on Windows (Developer Mode)**
  - Cause: Flutter web/desktop build on Windows requires symlink support.
  - Fix: enable “Developer Mode” in Windows settings, or run on a physical/emulated device.

Use this section when explaining real‑world issues and how you diagnosed them during development.

---

## 12. Future Improvements

- Sync Hive attendance data back to Firebase for centralized analytics.
- Add dashboards (per‑event, per‑department attendance statistics).
- Role‑based access beyond admin vs scanner (e.g. read‑only viewer).
- Smarter offline reconciliation when multiple devices scan the same event.
- Automated tests for admin portal grid logic and import/export flows.

This extended README should give new contributors and examiners a complete picture of what the system does, how it is structured, and how to run and reason about it.
