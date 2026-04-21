# Heart BP

Heart BP is a Flutter app for quickly logging blood pressure readings from a monitor photo. It uses on-device OCR to pre-fill systolic, diastolic, and pulse values, then stores a validated, local history and allows exporting that history as PDF.

## What this app does

- Capture a reading photo with the device camera or import one from files.
- Run ML Kit text recognition and parse values from the image.
- Show parsed values in a review sheet where each field can be edited before saving.
- Persist readings in a local SQLite database and keep the photo locally.
- Classify each reading into blood pressure categories (normal/elevated/high/crisis).
- Show latest/recent readings, full history, and detailed reading view with zoomable photo.
- Export all saved readings to a PDF report and share it.
- Delete readings, removing both DB row and stored photo.

## Project structure

`lib/src/app.dart`

- Wires the app shell with injected dependencies:
  - `ReadingRepository` for persistence.
  - `CaptureAndScanService` for camera/file input + OCR extraction.

`lib/src/services/`

- `capture_and_scan_service.dart`
  - Camera capture flow via `camera` plugin.
  - File-picker flow for existing photos.
  - OCR preprocessing and targeted metric extraction (display/systolic/diastolic/pulse crops).
- `ocr_parser.dart`
  - Parses SYS/DIA/PULSE from raw OCR text.
  - Supports fuzzy token normalization (common OCR character confusions, scoring, fallback heuristics).
- `reading_validator.dart`
  - Range validation: systolic 50–260, diastolic 30–180, pulse 30–220.

`lib/src/data/`

- `readings_database.dart`
  - Creates `readings` SQLite table.
- `sqlite_reading_repository.dart`
  - Implements CRUD and stream-based list watching.
  - Generates PDF exports via `pdf` package.
- `reading_repository.dart`
  - Repository interface used by app logic.

`lib/src/models/`

- `reading.dart` defines the stored model and pressure-level classification.
- `reading_draft.dart` is the editable pre-save shape.

UI files include the home screen, history list, detail screen, and shared glassmorphism widgets (`lib/src/screens`, `lib/src/widgets`).

## Local data and privacy

- Readings are stored only in the app’s local database.
- Photos are copied into the app documents directory under `reading_photos`.
- No backend sync is implemented in this repository.

## Run this project

### Prerequisites

- Flutter SDK (Dart 3.11+), matching the project’s SDK constraint.
- Android/iOS development setup for your target device.

### Commands

```bash
flutter pub get
flutter run
```

### Testing

```bash
flutter test
```

Test coverage currently includes:

- OCR parser behavior and OCR typo tolerance.
- Input validation rules.
- Pressure-level classification.
- SQLite repository save/read/watch/delete/report creation.
- Core widget behavior (home state and empty history flow).

## Project details

- App name: `heart_bp`
- Version: `1.0.0+1`
- Main dependencies:
  - `camera`, `google_mlkit_text_recognition`
  - `sqflite`, `path_provider`, `path`
  - `intl`, `file_picker`, `image`, `pdf`, `printing`

This README intentionally reflects current app behavior; if you want, I can also add a `screenshots/` section and a troubleshooting section for common capture/OCR failure cases. 
