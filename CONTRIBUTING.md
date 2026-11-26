# Contributing

Thank you for your interest in contributing to **LedgerFlow**.

## Development Setup

```bash
# Prerequisites: Flutter 3.41+, Android SDK (for APK builds)
git clone https://github.com/bachiep/ledgerflow-flutter.git
cd ledgerflow-flutter
flutter pub get
flutter analyze --no-pub
flutter test --concurrency=1       # run full test suite (62 tests)
```

## Workflow

1. **Open an Issue** describing the bug or feature.
2. **Create a branch** from `main`: `feat/issue-<n>-<slug>` or `fix/issue-<n>-<slug>`.
3. **Write widget/unit tests** for any new logic or UI.
4. **Follow Conventional Commits**: `feat(ledger): add multi-currency support (#5)`.
5. **Ensure CI passes**: `flutter analyze && flutter test` locally before pushing.
6. **Open a Pull Request** referencing the issue: `Closes #<n>`.

## Code Standards

- Flutter 3.41+ with Dart null-safety.
- BLoC pattern: `Bloc`/`Cubit` for state management, never `setState` in production widgets.
- Drift (SQLite) for local persistence — migrations via `schemaVersion` bumps.
- Offline-first: all CRUD operations must work without network.

## Web Demo

The live web demo auto-deploys to GitHub Pages on `main` push via `.github/workflows/pages.yml`.