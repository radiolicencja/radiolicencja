# Radiolicencja

Radio Licencja is a Flutter learning companion that renders quizzes directly from YAML topic assets. It supports both classic exam sessions and a learning mode powered by a lightweight spaced-repetition engine that keeps resurfacing the questions you struggle with the most.

## Key Features

- **File-based curriculum** – Topics are authored as YAML files under `assets/topics` and are pulled in automatically at runtime.
- **Two quiz modes** – "Test" mode walks through each question once; "Learning" mode keeps resurfacing questions (even after everything was mastered previously) until the current session is done.
- **Spaced repetition** – The `LearningQuestionPicker` class prioritizes questions using incorrect counts, mastery level, and recency (with a short-term penalty to avoid instant repeats) and automatically falls back to the full bank when every card is already mastered.
- **Per-question memory** – Correct/incorrect totals and the `last_seen` timestamp are persisted via `LearningProgressService` so learning sessions continue where you left off.
- **Stats dashboard** – Every topic card exposes a statistics sheet listing accuracy, last-seen time, picker weight, and the correct answer for each question.
- **Full i18n** – UI strings live in `lib/l10n/` (currently English and Polish) so adding languages is straightforward.
- **Rich Markdown + LaTeX** – All prompts, answers, and explanations run through [`gpt_markdown`](https://pub.dev/packages/gpt_markdown), so inline math (`$S_{11}$`), block equations, images, and tables render exactly as authored in YAML.
- **Answer-specific explanations** – Learning mode surfaces the matching Markdown explanation for the chosen answer (including an “I don’t know” fallback) to reinforce the concept immediately.
- **Floating action workflow** – A persistent bottom CTA handles advancing between questions, includes an auto-advance countdown/progress bar in learning mode, and pauses when the learner taps the screen.

## Architecture at a Glance

| Path | Responsibility |
| --- | --- |
| `lib/main.dart` | Boots the MaterialApp, localization, and route to the topic list. |
| `lib/topics.dart` | Loads YAML topics, renders the topic list, handles reset/statistics actions, and launches quizzes. |
| `lib/quiz.dart` | Quiz UI + learning flow, including Markdown/LaTeX rendering, contextual explanations, scoring, learning queue management, and stat recording. |
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
test_question_limit: 25
questions:
  - text: Example multiple-choice question?
    answers:
      - First option
      - Second option
      - Third option
    correct_index: 1
    explanations:
      - "Why option A is wrong..."
      - "Detailed reasoning for the correct answer."
      - "What makes option C incorrect."
      - "Fallback text for \"I don't know\"."
  - type: open
    text: Which call is used for emergencies?
    answers:
      - Mayday
      - MAYDAY
    explanations:
      - "Congrats — `MAYDAY` is the internationally recognized distress call."
      - "If you're unsure, remember that `MAYDAY` is reserved for life-threatening emergencies."
```

Field reference:

- `title`, `slug`, `description`, `image`: topic metadata displayed on the list.
- `test_question_limit`: optional cap (default **20**) for how many questions are pulled into a test session. Learning mode always uses the full question bank.
- `questions`: array of question objects.
  - Multiple-choice: omit `type`, provide `answers` as strings, and either use `correct_index` (0-based or letter) or set `correct: true` in the answer map. Optional `explanations` may contain:
    1. Markdown for answer A
    2. Markdown for answer B
    3. ...
    - Final entry reserved for the “I don’t know” button if present. Any missing entries are gracefully ignored.
  - Open questions: set `type: open` and enumerate acceptable answers inside `answers`. User responses are normalized (case-insensitive, punctuation trimmed) before comparison. `explanations` can include two Markdown snippets (correct first, incorrect second) plus an optional “I don’t know” tail.
+ All `text`, `answers`, and `explanations` support full Markdown plus LaTeX (rendered through `gpt_markdown`).

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
flutter build apk --release   # generate a Play Store-ready Android APK
```

The learning logic is all in Dart, so no native platform setup is required beyond Flutter's default toolchain.

## Localization

Strings live in `lib/l10n/app_*.arb`. After editing the ARB files, run `flutter gen-l10n` (handled automatically by Flutter builds) to regenerate `app_localizations.dart`. Keep translations synchronized when introducing new UI copy such as stats messages.

## UI/UX Notes

- **Topics list** intentionally uses text-only cards for a dense overview; progress and confidence badges stay visible even on small devices.
- **Next question button** floats above the content and doubles as the auto-advance indicator in learning mode. The countdown bar and helper text reflect how long until the app moves forward automatically.
- **Learning completion** screens now only appear when you finish the *current* session; sessions can always be restarted even if everything was previously mastered.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for coding standards, testing expectations, and the review process.

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for the full text.
