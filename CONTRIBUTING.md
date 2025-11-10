# Contributing to Radio Licencja

Thanks for your interest in improving the project! This guide explains the local workflow, coding expectations, and the review checklist we follow.

## 1. Project Setup

1. [Install Flutter](https://docs.flutter.dev/get-started/install) and ensure `flutter doctor` completes without issues.
2. Clone the repository and fetch dependencies:
   ```bash
   flutter pub get
   ```
3. (Optional) If you edit localization strings, run `flutter gen-l10n` or simply rebuild; Flutter regenerates the localization classes automatically during builds.

## 2. Development Workflow

- **Branching** – Create a feature branch per change set. Keep the scope focused: one bug fix or feature per PR.
- **Style & linting** – Follow the default Dart formatter (`dart format .`) and keep `flutter analyze` clean. Prefer small, descriptive widgets/services over monolithic files.
- **Testing** – Run:
  ```bash
  flutter analyze
  ```
  Add widget/unit tests when possible (e.g., for services and pickers). If you add logic to `LearningQuestionPicker`, consider covering it with a pure Dart test.
- **Assets & localization** – When adding strings, update both `app_en.arb` and `app_pl.arb`, regenerate localizations, and mention the new copy in your PR description.

## 3. Submitting Changes

1. Ensure `flutter analyze` passes.
2. Update relevant documentation (README, topic schema examples, etc.).
3. Squash obvious fixup commits before opening the PR.
4. Open a pull request that:
   - Describes _what_ changed and _why_.
   - Notes any manual testing performed (devices, scenarios).
   - Mentions new assets, localization keys, or migrations.

## 4. Code Review Expectations

- Be responsive to review feedback and keep discussions polite.
- Provide follow-up commits instead of force-pushing unless asked.
- Reviewers will check for:
  - Regression risks in quiz/learning flows.
  - Localization coverage.
  - Performance of repeated operations (e.g., sorting, SharedPreferences access).

## 5. Release & Licensing

By contributing, you agree that your work will be licensed under the [Apache License 2.0](LICENSE). Do not submit third-party code unless it is compatible with this license and clearly attributed.

Happy hacking!
