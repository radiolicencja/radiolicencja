import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:yaml/yaml.dart';

import 'l10n/app_localizations.dart';
import 'services/learning_progress.dart';

enum QuizQuestionType { multipleChoice, open }
enum QuizMode { test, learning }

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.topicSlug,
    required this.topicTitle,
    required this.questions,
    required this.mode,
    this.progressService,
  });

  final String topicSlug;
  final String topicTitle;
  final List<QuizQuestion> questions;
  final QuizMode mode;
  final LearningProgressService? progressService;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQuestion> _questions;
  late final int _totalQuestions;
  final Set<int> _masteredQuestionIds = <int>{};
  int _currentQuestionIndex = 0;
  int _score = 0;
  QuizAnswer? _selectedAnswer;
  bool _showSummary = false;
  bool? _openAnswerCorrect;
  final TextEditingController _openAnswerController = TextEditingController();
  final FocusNode _openAnswerFocus = FocusNode();
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    final initialQuestions = List<QuizQuestion>.from(widget.questions);
    final storedMastered =
        widget.progressService?.getMastered(widget.topicSlug) ?? <int>{};
    _masteredQuestionIds.addAll(storedMastered);
    if (widget.mode == QuizMode.learning) {
      initialQuestions
          .removeWhere((question) => storedMastered.contains(question.id));
      _totalQuestions = widget.questions.length;
      if (initialQuestions.isEmpty) {
        _showSummary = true;
      }
    } else {
      _totalQuestions = initialQuestions.length;
    }
    _questions = initialQuestions..shuffle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFocusForCurrentQuestion();
    });
  }

  @override
  void dispose() {
    _openAnswerController.dispose();
    _openAnswerFocus.dispose();
    super.dispose();
  }

  void _selectAnswer(QuizAnswer answer) {
    if (_selectedAnswer != null || _showSummary) return;
    final questionIndex = _currentQuestionIndex;
    final question = _questions[questionIndex];
    setState(() {
      _selectedAnswer = answer;
      if (answer.isCorrect) {
        _score++;
      }
    });
    if (answer.isCorrect) {
      _recordMastered(question);
      _scheduleAdvanceAfterCorrect(questionIndex);
    }
  }

  void _submitOpenAnswer(QuizQuestion question) {
    if (_openAnswerCorrect != null || _showSummary) return;
    final response = _openAnswerController.text.trim();
    if (response.isEmpty) return;
    final isCorrect = question.matchesOpenResponse(response);
    final questionIndex = _currentQuestionIndex;
    setState(() {
      _openAnswerCorrect = isCorrect;
      if (isCorrect) {
        _score++;
      }
    });
    if (isCorrect) {
      _recordMastered(question);
      _openAnswerFocus.unfocus();
      _scheduleAdvanceAfterCorrect(questionIndex);
    }
  }

  void _goToNextStep() {
    if (widget.mode == QuizMode.learning) {
      final wasCorrect = _currentQuestionWasAnsweredCorrectly;
      setState(() {
        _advanceLearningQueue(wasCorrect);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureFocusForCurrentQuestion();
      });
      return;
    }
    if (_currentQuestionIndex >= _questions.length - 1) {
      setState(() {
        _showSummary = true;
      });
    } else {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _openAnswerCorrect = null;
        _openAnswerController.clear();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFocusForCurrentQuestion();
    });
  }

  void _ensureFocusForCurrentQuestion() {
    if (!mounted || _showSummary || _currentQuestionIndex >= _questions.length) {
      return;
    }
    final question = _questions[_currentQuestionIndex];
    if (question.isOpen && _openAnswerCorrect == null) {
      _openAnswerFocus.requestFocus();
    } else {
      _openAnswerFocus.unfocus();
    }
  }

  bool get _currentQuestionWasAnsweredCorrectly {
    return (_selectedAnswer?.isCorrect ?? false) || (_openAnswerCorrect == true);
  }

  void _advanceLearningQueue(bool answeredCorrect) {
    if (_questions.isEmpty) {
      return;
    }
    final question = _questions.removeAt(_currentQuestionIndex);
    if (!answeredCorrect) {
      final insertIndex =
          _questions.isEmpty ? 0 : _random.nextInt(_questions.length + 1);
      _questions.insert(insertIndex, question);
      if (insertIndex <= _currentQuestionIndex) {
        _currentQuestionIndex++;
      }
    }
    if (_questions.isEmpty) {
      _selectedAnswer = null;
      _openAnswerCorrect = null;
      _openAnswerController.clear();
      _showSummary = true;
      return;
    }
    if (_currentQuestionIndex >= _questions.length) {
      _currentQuestionIndex = 0;
    }
    _selectedAnswer = null;
    _openAnswerCorrect = null;
    _openAnswerController.clear();
  }

  void _scheduleAdvanceAfterCorrect(int questionIndex) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _showSummary) return;
      if (_currentQuestionIndex != questionIndex) return;
      _goToNextStep();
    });
  }

  void _recordMastered(QuizQuestion question) {
    if (widget.mode != QuizMode.learning) return;
    if (_masteredQuestionIds.contains(question.id)) return;
    _masteredQuestionIds.add(question.id);
    final service = widget.progressService;
    if (service != null) {
      unawaited(service.markMastered(widget.topicSlug, question.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty && !_showSummary) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.topicTitle)),
        body: const Center(
          child: _NoQuestionsMessage(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topicTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _showSummary ? _buildSummary(context) : _buildQuestionView(context),
      ),
    );
  }

  int get _masteredCount =>
      _masteredQuestionIds.length.clamp(0, _totalQuestions);

  Widget _buildQuestionView(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final question = _questions[_currentQuestionIndex];
    final progressText = widget.mode == QuizMode.learning
        ? l10n.quizLearningProgress(_masteredCount, _totalQuestions)
        : l10n.quizQuestionProgress(_currentQuestionIndex + 1, _questions.length);
    final commonHeader = <Widget>[
      Text(
        progressText,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Colors.grey[600]),
      ),
      const SizedBox(height: 12),
      _QuestionMarkdown(text: question.text),
      const SizedBox(height: 24),
    ];

    if (question.isOpen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...commonHeader,
          _buildOpenQuestion(context, question),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...commonHeader,
        _buildMultipleChoiceQuestion(context, question),
      ],
    );
  }

  Widget _buildMultipleChoiceQuestion(
    BuildContext context,
    QuizQuestion question,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final nextButtonLabel = _currentQuestionIndex == _questions.length - 1
        ? l10n.quizButtonSeeScore
        : l10n.quizButtonNextQuestion;
    return Column(
      children: [
        ...question.answers.map(
          (answer) => _AnswerOption(
            answer: answer,
            isSelected: identical(_selectedAnswer, answer),
            revealCorrect: _selectedAnswer != null,
            onTap: () => _selectAnswer(answer),
          ),
        ),
        const SizedBox(height: 16),
        if (_selectedAnswer != null && !_selectedAnswer!.isCorrect) ...[
          Text(
            l10n.quizCorrectAnswerLabel(
              question.correctAnswer.label,
              question.correctAnswer.text,
            ),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.green[700]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _goToNextStep,
              child: Text(nextButtonLabel),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOpenQuestion(BuildContext context, QuizQuestion question) {
    final l10n = AppLocalizations.of(context)!;
    final nextButtonLabel = _currentQuestionIndex == _questions.length - 1
        ? l10n.quizButtonSeeScore
        : l10n.quizButtonNextQuestion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _openAnswerController,
          focusNode: _openAnswerFocus,
          readOnly: _openAnswerCorrect != null,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: l10n.quizYourAnswerLabel,
          ),
          onSubmitted: (_) {
            if (_openAnswerCorrect == null) {
              _submitOpenAnswer(question);
            } else {
              _goToNextStep();
            }
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _openAnswerCorrect == null
                ? () => _submitOpenAnswer(question)
                : (_openAnswerCorrect! ? null : _goToNextStep),
            child: Text(
              _openAnswerCorrect == null
                  ? l10n.quizButtonCheckAnswer
                  : (_openAnswerCorrect!
                      ? l10n.quizButtonCorrect
                      : nextButtonLabel),
            ),
          ),
        ),
        if (_openAnswerCorrect == false) ...[
          const SizedBox(height: 16),
          Text(
            l10n.quizWrongAnswerLabel,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.red),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.quizAcceptedAnswersLabel(
              question.acceptedAnswers.join(', '),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final summaryTitle = widget.mode == QuizMode.learning
        ? l10n.quizLearningCompleteTitle
        : l10n.quizTestCompleteTitle;
    final summaryBody = widget.mode == QuizMode.learning
        ? l10n.quizLearningCompleteBody(_totalQuestions)
        : l10n.quizTestCompleteBody(_score, _totalQuestions);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 72,
          color: Colors.green.shade600,
        ),
        const SizedBox(height: 16),
        Text(
          summaryTitle,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          summaryBody,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.quizBackToTopicsButton),
          ),
        ),
      ],
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.answer,
    required this.isSelected,
    required this.revealCorrect,
    required this.onTap,
  });

  final QuizAnswer answer;
  final bool isSelected;
  final bool revealCorrect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color? tileColor;
    if (revealCorrect) {
      if (answer.isCorrect) {
        tileColor = Colors.green.shade50;
      } else if (isSelected) {
        tileColor = Colors.red.shade50;
      }
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: tileColor,
      child: ListTile(
        title: Text('${answer.label}. ${answer.text}'),
        onTap: revealCorrect ? null : onTap,
        trailing: revealCorrect && answer.isCorrect
            ? const Icon(Icons.check, color: Colors.green)
            : revealCorrect && isSelected
                ? const Icon(Icons.close, color: Colors.red)
                : null,
      ),
    );
  }
}

class _NoQuestionsMessage extends StatelessWidget {
  const _NoQuestionsMessage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.quizNoQuestionsAvailable,
      textAlign: TextAlign.center,
    );
  }
}

class _QuestionMarkdown extends StatelessWidget {
  const _QuestionMarkdown({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.headlineSmall;
    final bodyStyle = theme.textTheme.bodyLarge;
    return MarkdownBody(
      data: text,
      sizedImageBuilder: (config) {
        final uri = config.uri;
        final width = config.width;
        final height = config.height;
        if (uri.scheme.isEmpty || uri.scheme == 'asset') {
          final path = uri.scheme == 'asset' ? uri.path : uri.toString();
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              path,
              width: width,
              height: height,
              fit: BoxFit.contain,
            ),
          );
        }
        return Image.network(
          uri.toString(),
          width: width,
          height: height,
          fit: BoxFit.contain,
        );
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: baseStyle,
        listBullet: bodyStyle,
      ),
    );
  }
}

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.text,
    required this.type,
    List<QuizAnswer> answers = const [],
    List<String> acceptedAnswers = const [],
  })  : answers = List.unmodifiable(answers),
        acceptedAnswers = List.unmodifiable(acceptedAnswers);

  final int id;
  final String text;
  final QuizQuestionType type;
  final List<QuizAnswer> answers;
  final List<String> acceptedAnswers;

  bool get isOpen => type == QuizQuestionType.open;

  QuizAnswer get correctAnswer {
    return answers.firstWhere(
      (answer) => answer.isCorrect,
      orElse: () => answers.isNotEmpty
          ? answers.first
          : QuizAnswer(
              label: 'A',
              text: 'No answer provided',
              isCorrect: true,
            ),
    );
  }

  bool matchesOpenResponse(String response) {
    if (!isOpen) return false;
    final normalizedAttempt = _normalizeAnswer(response);
    return acceptedAnswers.any(
      (answer) => _normalizeAnswer(answer) == normalizedAttempt,
    );
  }

  factory QuizQuestion.fromMap(
    Map<String, dynamic> map, {
    required int id,
  }) {
    final questionText = (map['text'] ?? '').toString().trim();
    final type = _parseType(map['type']);
    final answersRaw = map['answers'];
    final collectedAnswers = <String>[];
    int? flaggedIndex;

    if (answersRaw is Iterable) {
      for (final entry in answersRaw) {
        String? text;
        bool isFlagged = false;

        if (entry is String) {
          text = entry;
        } else if (entry is YamlScalar) {
          text = entry.value?.toString();
        } else if (entry is Map) {
          final normalized = Map<String, dynamic>.from(entry);
          text = (normalized['text'] ?? normalized['value'] ?? '').toString();
          isFlagged = normalized['correct'] == true;
        } else if (entry is YamlMap) {
          final normalized = Map<String, dynamic>.from(entry);
          text = (normalized['text'] ?? normalized['value'] ?? '').toString();
          isFlagged = normalized['correct'] == true;
        }

        text = text?.trim();
        if (text != null && text.isNotEmpty) {
          collectedAnswers.add(text);
          if (isFlagged) {
            flaggedIndex = collectedAnswers.length - 1;
          }
        }
      }
    }

    if (type == QuizQuestionType.open) {
      return QuizQuestion(
        id: id,
        text: questionText.isEmpty ? 'Untitled question' : questionText,
        type: QuizQuestionType.open,
        acceptedAnswers: collectedAnswers,
      );
    }

    final correctIndex = _resolveCorrectIndex(
      flaggedIndex: flaggedIndex,
      provided: map['correct_index'],
      answersCount: collectedAnswers.length,
    );

    final answers = List<QuizAnswer>.generate(
      collectedAnswers.length,
      (index) => QuizAnswer.fromText(
        collectedAnswers[index],
        index: index,
        isCorrect: index == correctIndex,
      ),
    );

    return QuizQuestion(
      id: id,
      text: questionText.isEmpty ? 'Untitled question' : questionText,
      type: QuizQuestionType.multipleChoice,
      answers: answers,
    );
  }

  static QuizQuestionType _parseType(Object? raw) {
    final value = raw?.toString().toLowerCase().trim();
    if (value == 'open' || value == 'text' || value == 'input') {
      return QuizQuestionType.open;
    }
    return QuizQuestionType.multipleChoice;
  }

  static String _normalizeAnswer(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int _resolveCorrectIndex({
    required int answersCount,
    int? flaggedIndex,
    Object? provided,
  }) {
    if (answersCount == 0) {
      return 0;
    }
    if (flaggedIndex != null &&
        flaggedIndex >= 0 &&
        flaggedIndex < answersCount) {
      return flaggedIndex;
    }
    final parsed = _parseCorrectIndex(provided, answersCount);
    if (parsed != null) {
      return parsed;
    }
    return 0;
  }

  static int? _parseCorrectIndex(Object? raw, int answersCount) {
    if (raw == null) return null;

    int? index;
    if (raw is int) {
      index = raw;
    } else if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final asInt = int.tryParse(trimmed);
      if (asInt != null) {
        index = asInt;
      } else {
        final upper = trimmed.toUpperCase();
        if (upper.length == 1) {
          final unit = upper.codeUnitAt(0);
          if (unit >= 65 && unit <= 90) {
            index = unit - 65;
          }
        }
      }
    }

    if (index == null) {
      return null;
    }
    if (index < 0 || index >= answersCount) {
      return null;
    }
    return index;
  }
}

class QuizAnswer {
  QuizAnswer({
    required this.label,
    required this.text,
    required this.isCorrect,
  });

  final String label;
  final String text;
  final bool isCorrect;

  factory QuizAnswer.fromText(
    String rawText, {
    required int index,
    required bool isCorrect,
  }) {
    final label = _autoLabel(index);
    final text = rawText.trim().isEmpty ? 'Answer $label' : rawText.trim();
    return QuizAnswer(
      label: label,
      text: text,
      isCorrect: isCorrect,
    );
  }

  static String _autoLabel(int index) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index >= 0 && index < letters.length) {
      return letters[index];
    }
    return 'Option';
  }
}
