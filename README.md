# Radiolicencja

Radio Licencja is a Flutter learning companion that renders quizzes directly from YAML topic assets. It supports both classic exam sessions and a learning mode powered by a lightweight spaced-repetition engine that keeps resurfacing the questions you struggle with the most.

## Key Features

- **File-based curriculum** – Topics are authored as YAML files under `assets/topics` and are pulled in automatically at runtime.
- **Two quiz modes** – "Test" mode walks through each question once; "Learning" mode loops until every question is mastered.
- **Spaced repetition** – The `LearningQuestionPicker` class prioritizes questions using incorrect counts, mastery level, and recency (with a short-term penalty to avoid instant repeats).
- **Per-question memory** – Correct/incorrect totals and the `last_seen` timestamp are persisted via `LearningProgressService` so learning sessions continue where you left off.
- **Stats dashboard** – Every topic card exposes a statistics sheet listing accuracy, last-seen time, picker weight, and the correct answer for each question.
- **Full i18n** – UI strings live in `lib/l10n/` (currently English and Polish) so adding languages is straightforward.

## Architecture at a Glance

| Path | Responsibility |
| --- | --- |
| `lib/main.dart` | Boots the MaterialApp, localization, and route to the topic list. |
| `lib/topics.dart` | Loads YAML topics, renders the topic list, handles reset/statistics actions, and launches quizzes. |
| `lib/quiz.dart` | Quiz UI + learning flow, including input handling, scoring, learning queue management, and stat recording. |
| `lib/services/learning_progress.dart` | Thin persistence layer on top of `SharedPreferences` that stores mastered IDs plus per-question stats (correct, incorrect, last_seen). |
| `lib/services/learning_question_picker.dart` | Central heuristic for ordering learning questions and exposing the same weight to the stats sheet. |
| `assets/topics/*.yaml` | Content bundle authored by instructors/editors. |

### Learning Engine

1. When you open a topic in learning mode the mastered questions are removed.
2. `LearningQuestionPicker` calculates a score for every remaining question:
   - Incorrect answers are weighted heavily (default 5×) so weak areas come first.
   - Accumulated correct answers subtract from the score to down-rank mastered cards (Leitner-style buckets).
   - Recency contributes a boost up to 72h, but anything seen in the last ~15 minutes gets a temporary negative weight to avoid back-to-back repeats.
   - A deterministic random tie-breaker keeps ordering stable without feeling mechanical.
3. Every answer submission calls `LearningProgressService.recordAnswerResult`, incrementing counts and recording `last_seen`, so the picker and stats sheet always operate on the latest data.

## Authoring Topics

Topics live under `assets/topics/` and follow the schema below:

```yaml
title: My Topic
slug: my-topic
description: Short summary shown in the list.
image: assets/images/example.png
questions:
  - text: Example multiple-choice question?
    answers:
      - First option
      - Second option
      - Third option
    correct_index: 1
  - type: open
    text: Which call is used for emergencies?
    answers:
      - Mayday
      - MAYDAY
```

Field reference:

- `title`, `slug`, `description`, `image`: topic metadata displayed on the list.
- `questions`: array of question objects.
  - Multiple-choice: omit `type`, provide `answers` as strings, and either use `correct_index` (0-based or letter) or set `correct: true` in the answer map.
  - Open questions: set `type: open` and enumerate acceptable answers inside `answers`. User responses are normalized (case-insensitive, punctuation trimmed) before comparison.

Changes to the asset folder are picked up automatically thanks to Flutter's asset manifest.

## Development

Prerequisites:

- Flutter 3.19+ (or the version defined by your local `flutter --version`).
- Dart SDK bundled with Flutter.

Common workflows:

```bash
flutter pub get        # install dependencies
flutter analyze        # static checks
flutter run            # launch on a device/emulator
```

The learning logic is all in Dart, so no native platform setup is required beyond Flutter's default toolchain.

## Localization

Strings live in `lib/l10n/app_*.arb`. After editing the ARB files, run `flutter gen-l10n` (handled automatically by Flutter builds) to regenerate `app_localizations.dart`. Keep translations synchronized when introducing new UI copy such as stats messages.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for coding standards, testing expectations, and the review process.

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for the full text.
