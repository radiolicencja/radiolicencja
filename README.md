# radiolicencja

A Flutter learning app that discovers topics bundled as YAML and renders quizzes/learning sessions directly from those assets.

## Authoring topics

Topics live under `assets/topics/` and are picked up automatically via the Flutter asset manifest. Each file should contain a single topic with the following shape:

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

### Field reference

- `title`, `slug`, `description`, `image`: metadata surfaced on the topic list.
- `questions`: array of question entries.
  - For multiple-choice questions omit `type` (defaults to `multipleChoice`), supply `answers` as a list of strings, and point to the correct choice using `correct_index` (zero-based) or, alternatively, mark an answer map with `correct: true`.
  - For open questions set `type: open` and provide every accepted response value inside `answers`. User input is normalized (case-insensitive, punctuation removed) before comparison.

No localization is required for topics; the application UI is localized separately via `lib/l10n`.
