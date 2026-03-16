# QR Scanner Attendance App

Offline-first Flutter app for college event attendance using barcode scanning.

This project manages:
- Events and venues
- Barcode scans per event
- Entry or Exit attendance actions
- Department mapping from roll-number prefixes
- Student master import (CSV/XLSX) for offline profile resolution
- Event-level scan policies (scan mode, cooldown, duplicate-exit restriction)
- Offline analytics counters for operations
- Excel export of attendance data

## 1. Project Purpose

This app is designed for engineering college events where each student has a barcode containing a roll number (example: `23ALR109`).

From this roll number, the app derives:
- Batch year (`23` -> `2023`)
- Department code (`ALR` -> department name from settings)
- Roll suffix (`109`)

The app records timestamped event attendance as Entry and Exit logs.

## 2. Functional Flow (Validated)

The flow implemented now is:

1. Add event with name and venue from Home screen.
2. Open an event.
3. Tap camera button to scan barcode.
4. After scan, app asks action in popup: `Entry` or `Exit`.
	- Student profile card is shown before action confirmation.
	- Quick action chips: `Entry`, `Exit`, `Cancel`.
5. App validates barcode format (`2 digits + 2-4 letters + 3 digits`).
6. App stores/update attendance with human-readable timestamps.
7. Event screen shows live attendance list.
8. Export event attendance to Excel.

This matches your expected usage pattern for attendance operations.

## 3. Refactor and Bug Fixes Completed

### Critical issues fixed

- Fixed broken Event screen workflow:
	- Previously, Event screen only showed static text and did not expose the scan flow in UI.
	- Now Event screen includes scan button, popup action selection, and attendance list.
- Added Entry/Exit popup confirmation per scan.
- Improved barcode parsing:
	- Department extraction now supports `2-4` character codes (for values like `ALR`, `ALL`).
- Added student year derivation utility from batch year.
- Added readable timestamp formatting.
- Added validation to prevent duplicate active entry without exit.
- Added safe handling for Exit when no open Entry exists.
- Fixed Home screen initialization safety around event box loading.
- Added more default department aliases (`ALR`, `ALL`, `AID`, `ML`, `DS`).
- Fixed dependency management:
	- moved `hive_generator` and `build_runner` to `dev_dependencies`
	- pinned `build_runner` to a compatible version

### Cleanup completed

- Removed duplicate and unused code files that increased maintenance risk.

## 4. Current Code Structure

```
lib/
	main.dart
	app/
		app.dart
		bootstrap.dart
	features/
		analytics/
			data/
				scan_analytics_service.dart
		attendance/
			data/
				excel_export.dart
				hive_attendee_store.dart
			domain/
				entities/
					attendee.dart
					attendee.g.dart
				services/
					attendance_flow_service.dart
					scan_policy_service.dart
				utils/
					roll_number_parser.dart
			presentation/
				screens/
					barcode_scanner_screen.dart
					event_screen.dart
		events/
			data/
				hive_event_repository.dart
			domain/
				entities/
					event.dart
					event.g.dart
				repositories/
					event_repository.dart
			presentation/
				screens/
					home_screen.dart
		settings/
			data/
				settings_service.dart
			domain/
				repositories/
					settings_repository.dart
			presentation/
				screens/
					settings_screen.dart
		students/
			data/
				hive_student_repository.dart
				student_import_service.dart
			domain/
				entities/
					student.dart
					student.g.dart
				repositories/
					student_repository.dart
```

## 5. Data Model

### Event
- `name`
- `venue`
- `date`

### Attendee
- `id` (full roll number, e.g. `23ALR109`)
- `name` (currently `Unknown`, ready for future student master mapping)
- `batch` (e.g. `2023`)
- `department` (resolved from settings map)
- `inTime`
- `outTime` (nullable)
- `eventName`

## 6. Department Mapping

Department mapping is configurable in Settings and saved via `SharedPreferences`.

Default mapping includes common departments plus aliases for AI-related codes. Add more aliases as needed (for example multiple prefixes for same department).

## 7. Student Master Module (Implemented)

Offline student data module is now active.

- Import CSV or XLSX from Settings screen.
- Required key column: roll number (`rollno` / `roll_number` / `roll`).
- Optional columns: `name`, `mobileno`, `branch`, `section`, `hosteller_or_dayscholar`.
- Student profile is resolved instantly during scan and shown in a profile card before action confirmation.

## 8. Event Policy Controls (Implemented)

Each event now supports:

- `Scan Mode`: `Both`, `Entry Only`, `Exit Only`
- `Cooldown (seconds)`: block rapid accidental repeated scans
- `Restrict Duplicate Exit`: prevents repeated exit actions without new entry

## 9. Analytics (Implemented)

Offline analytics stored via local preferences:

- successful scans count
- invalid scans count
- duplicate entry attempts
- duplicate exit attempts
- export success count
- export failure count

Visible from Settings screen for operations monitoring.

## 10. Production-Grade Industry Refactor Guide

Based on Flutter architecture guidance and common production patterns, this app should evolve to:

1. Feature-first modules
	 - `features/events`, `features/attendance`, `features/settings`, `features/students`
2. Layered architecture
	 - `presentation` (UI), `application` (use-cases), `domain` (entities/rules), `data` (Hive/Prefs adapters)
3. State management standardization
	 - Adopt one approach consistently (for example Riverpod/Bloc)
4. Repository abstraction
	 - isolate Hive and SharedPreferences behind repositories for easier testing
5. Input validation and error boundaries
	 - reusable validators for roll format and event fields
6. Test coverage
	 - unit tests for parser and attendance rules
	 - widget tests for event flow and dialogs
7. Release readiness
	 - app signing, versioning, icon/branding, crash logging, analytics (optional)

Status: feature-first architecture is now implemented in code.

## 11. Recommended Final Folder Target

```
lib/
	app/
		app.dart
		router.dart
	core/
		constants/
		errors/
		utils/
	features/
		events/
			data/
			domain/
			presentation/
		attendance/
			data/
			domain/
			presentation/
		settings/
			data/
			domain/
			presentation/
		students/
			data/
			domain/
			presentation/
```

## 12. Student Master Data (Future Roadmap)

Planned enhancement for ML/DS offline dataset:

- Add local student table keyed by roll number.
- On scan, enrich attendee record with:
	- student name
	- mobile number
	- hosteller/day scholar
	- branch
	- section
- Show enriched profile on Event screen while keeping attendance action popup.

## 13. Build and Run

### Prerequisites
- Flutter SDK
- Android Studio / VS Code
- Device or emulator

### Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### Release (Android)

```bash
flutter build appbundle
```

Use proper signing configuration before publishing.

## 14. CI Reliability (Implemented)

GitHub Actions workflow is added:

- File: `.github/workflows/ci.yml`
- Runs on push and pull requests
- Executes:
	- `flutter pub get`
	- `flutter analyze`
	- `flutter test`

Merges should be blocked when CI fails.

## 15. Quality Status

- `flutter analyze`: clean (no issues)
- `flutter test`: all tests passed
- Core event attendance flow: implemented and verified in code
- Ready for APK/internal testing

## 16. Notes

- This app is offline-first for attendance operations.
- Student identity enrichment is intentionally future-ready and can be added without changing current attendance schema.
