import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:yaml/yaml.dart';

import 'l10n/app_localizations.dart';
import 'services/learning_progress.dart';
import 'services/learning_question_picker.dart';

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

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _learningAutoAdvanceDuration = Duration(seconds: 5);
  late final List<QuizQuestion> _questions;
  late final int _totalQuestions;
  final Set<int> _masteredQuestionIds = <int>{};
  late final Map<int, QuestionStats> _questionStats;
  LearningQuestionPicker<QuizQuestion>? _learningPicker;
  int _currentQuestionIndex = 0;
  int _score = 0;
  QuizAnswer? _selectedAnswer;
  final QuizAnswer _iDontKnowAnswer = QuizAnswer(
    label: '--',
    text: "I don't know",
    isCorrect: false,
  );
  bool _showSummary = false;
  bool? _openAnswerCorrect;
  final TextEditingController _openAnswerController = TextEditingController();
  final FocusNode _openAnswerFocus = FocusNode();
  final Random _random = Random();
  bool _autoAdvancePaused = false;
  late final AnimationController _autoAdvanceController;
  int? _autoAdvanceQuestionIndex;
  bool _usedIDontKnow = false;
  int? _lastMatchedOpenAnswerIndex;

  @override
  void initState() {
    super.initState();
    final initialQuestions = List<QuizQuestion>.from(widget.questions);
    _questionStats = Map<int, QuestionStats>.from(
      widget.progressService?.getQuestionStats(widget.topicSlug) ??
          <int, QuestionStats>{},
    );
    final storedMastered =
        widget.progressService?.getMastered(widget.topicSlug) ?? <int>{};
    _masteredQuestionIds.addAll(storedMastered);
    if (widget.mode == QuizMode.learning) {
      _learningPicker = LearningQuestionPicker<QuizQuestion>(
        stats: _questionStats,
        idResolver: (question) => question.id,
        random: _random,
      );
      initialQuestions
          .removeWhere((question) => storedMastered.contains(question.id));
      if (initialQuestions.isEmpty && widget.questions.isNotEmpty) {
        initialQuestions.addAll(widget.questions);
      }
      _totalQuestions = widget.questions.length;
      _learningPicker?.sort(initialQuestions);
    } else {
      initialQuestions.shuffle(_random);
      _totalQuestions = initialQuestions.length;
    }
    _questions = initialQuestions;
    _autoAdvanceController = AnimationController(
      vsync: this,
      duration: _learningAutoAdvanceDuration,
    )
      ..addListener(() {
        if (!mounted) return;
        if (_autoAdvanceController.isAnimating) {
          setState(() {});
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _handleAutoAdvanceComplete();
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureFocusForCurrentQuestion();
    });
  }

  @override
  void dispose() {
    _cancelAutoAdvanceCountdown();
    _autoAdvanceController.dispose();
    _openAnswerController.dispose();
    _openAnswerFocus.dispose();
    super.dispose();
  }

  void _handleUserInteraction() {
    if (!_isAutoAdvancePauseAvailable) return;
    setState(() {
      _autoAdvancePaused = true;
    });
    _autoAdvanceController.stop();
  }

  bool get _isAutoAdvancePauseAvailable {
    return widget.mode == QuizMode.learning &&
        !_autoAdvancePaused &&
        _autoAdvanceController.isAnimating;
  }

  void _cancelAutoAdvanceCountdown() {
    _autoAdvanceQuestionIndex = null;
    if (_autoAdvanceController.isAnimating ||
        _autoAdvanceController.value != 0) {
      _autoAdvanceController.stop();
      _autoAdvanceController.value = 0;
    }
    _autoAdvancePaused = false;
  }

  void _startAutoAdvanceCountdown(int questionIndex) {
    if (widget.mode != QuizMode.learning) return;
    _autoAdvanceQuestionIndex = questionIndex;
    setState(() {
      _autoAdvancePaused = false;
    });
    _autoAdvanceController
      ..stop()
      ..reset()
      ..forward();
  }

  void _handleAutoAdvanceComplete() {
    if (!mounted ||
        _autoAdvancePaused ||
        _showSummary ||
        _autoAdvanceQuestionIndex != _currentQuestionIndex) {
      return;
    }
    _autoAdvanceQuestionIndex = null;
    _goToNextStep();
  }

  bool get _isAutoAdvanceRunning {
    return widget.mode == QuizMode.learning &&
        !_autoAdvancePaused &&
        _autoAdvanceQuestionIndex == _currentQuestionIndex &&
        _autoAdvanceController.isAnimating;
  }

  double? get _autoAdvanceProgress {
    if (!_isAutoAdvanceRunning) return null;
    return _autoAdvanceController.value.clamp(0.0, 1.0);
  }

  int get _autoAdvanceRemainingSeconds {
    final remainingMs =
        (1 - _autoAdvanceController.value) * _learningAutoAdvanceDuration.inMilliseconds;
    var seconds = (remainingMs / 1000).ceil();
    if (seconds < 0) {
      seconds = 0;
    } else if (seconds > _learningAutoAdvanceDuration.inSeconds) {
      seconds = _learningAutoAdvanceDuration.inSeconds;
    }
    return seconds;
  }

  void _selectAnswer(QuizAnswer answer) {
    if (_selectedAnswer != null || _showSummary) return;
    final questionIndex = _currentQuestionIndex;
    final question = _questions[questionIndex];
    final answeredIDontKnow = identical(answer, _iDontKnowAnswer);
    // Multiple-choice answers are resolved entirely through the QuizAnswer.isCorrect flag.
    // The question data already marks the right option, so we just trust that metadata here.
    setState(() {
      _selectedAnswer = answer;
      _usedIDontKnow = answeredIDontKnow;
      _lastMatchedOpenAnswerIndex = null;
      if (answer.isCorrect) {
        _score++;
      }
    });
    _recordAnswerResult(question, answer.isCorrect);
    if (answer.isCorrect) {
      _recordMastered(question);
      _scheduleAdvanceAfterCorrect(questionIndex);
    }
  }

  void _submitOpenAnswer(QuizQuestion question) {
    if (_openAnswerCorrect != null || _showSummary) return;
    final response = _openAnswerController.text.trim();
    if (response.isEmpty) return;
    final matchIndex = question.acceptedAnswerIndexFor(response);
    // For open questions we normalise the user input and compare it against every accepted answer,
    // treating the first successful match as the canonical "correct" response for scoring/explanations.
    final isCorrect = matchIndex != null;
    final questionIndex = _currentQuestionIndex;
    setState(() {
      _openAnswerCorrect = isCorrect;
      _lastMatchedOpenAnswerIndex = matchIndex;
      _usedIDontKnow = false;
      if (isCorrect) {
        _score++;
      }
    });
    _recordAnswerResult(question, isCorrect);
    if (isCorrect) {
      _recordMastered(question);
      _openAnswerFocus.unfocus();
      _scheduleAdvanceAfterCorrect(questionIndex);
    }
  }

  void _handleIDontKnow(QuizQuestion question) {
    if (widget.mode != QuizMode.learning || _showSummary) return;
    if (question.isOpen) {
      if (_openAnswerCorrect != null) return;
      setState(() {
        _openAnswerCorrect = false;
        _usedIDontKnow = true;
        _lastMatchedOpenAnswerIndex = null;
      });
      _openAnswerFocus.unfocus();
      _recordAnswerResult(question, false);
    } else {
      if (_selectedAnswer != null) return;
      _selectAnswer(_iDontKnowAnswer);
    }
  }

  void _goToNextStep() {
    _cancelAutoAdvanceCountdown();
    if (widget.mode == QuizMode.learning) {
      final wasCorrect = _currentQuestionWasAnsweredCorrectly;
      setState(() {
        _autoAdvancePaused = false;
        _advanceLearningQueue(wasCorrect);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureFocusForCurrentQuestion();
      });
      return;
    }
    if (_currentQuestionIndex >= _questions.length - 1) {
      setState(() {
        _autoAdvancePaused = false;
        _usedIDontKnow = false;
        _lastMatchedOpenAnswerIndex = null;
        _showSummary = true;
      });
    } else {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _openAnswerCorrect = null;
        _openAnswerController.clear();
        _autoAdvancePaused = false;
        _usedIDontKnow = false;
        _lastMatchedOpenAnswerIndex = null;
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
    _cancelAutoAdvanceCountdown();
    _autoAdvancePaused = false;
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
      _lastMatchedOpenAnswerIndex = null;
      _showSummary = true;
      return;
    }
    if (_currentQuestionIndex >= _questions.length) {
      _currentQuestionIndex = 0;
    }
    _selectedAnswer = null;
    _openAnswerCorrect = null;
    _openAnswerController.clear();
    _usedIDontKnow = false;
    _lastMatchedOpenAnswerIndex = null;
  }

  void _scheduleAdvanceAfterCorrect(int questionIndex) {
    if (widget.mode == QuizMode.learning) {
      _startAutoAdvanceCountdown(questionIndex);
      return;
    }
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

  void _recordAnswerResult(QuizQuestion question, bool isCorrect) {
    final service = widget.progressService;
    if (service == null) return;
    final current = _questionStats[question.id] ?? const QuestionStats();
    final now = DateTime.now();
    final updated = isCorrect
        ? current.incrementCorrect(now)
        : current.incrementIncorrect(now);
    _questionStats[question.id] = updated;
    unawaited(
      service.recordAnswerResult(
        widget.topicSlug,
        question.id,
        isCorrect: isCorrect,
      ),
    );
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          _showSummary ? null : _buildBottomAction(context),
      body: Listener(
        onPointerDown: (_) => _handleUserInteraction(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _showSummary
              ? _buildSummary(context)
              : _buildQuestionView(context),
        ),
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
    ];
    final questionBody = question.isOpen
        ? _buildOpenQuestion(context, question)
        : _buildMultipleChoiceQuestion(context, question);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          primary: false,
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 120),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...commonHeader,
                const SizedBox(height: 24),
                questionBody,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? _buildBottomAction(BuildContext context) {
    if (_showSummary || _questions.isEmpty) {
      return null;
    }
    final l10n = AppLocalizations.of(context)!;
    final question = _questions[_currentQuestionIndex];
    final isLast = _currentQuestionIndex == _questions.length - 1;
    final nextLabel =
        isLast ? l10n.quizButtonSeeScore : l10n.quizButtonNextQuestion;

    final double? autoProgressValue = _autoAdvanceProgress;
    final bool showAutoProgress = autoProgressValue != null;
    final String? helperText =
        showAutoProgress ? l10n.quizAutoAdvanceHint(_autoAdvanceRemainingSeconds) : null;

    if (question.isOpen) {
      if (_openAnswerCorrect == null) {
        return null;
      }
      final answeredCorrect = _openAnswerCorrect!;
      if (answeredCorrect && widget.mode != QuizMode.learning) {
        return null;
      }
      return _FloatingBottomButton(
        label: nextLabel,
        onPressed: _goToNextStep,
        autoProgress: autoProgressValue,
        helperText: helperText,
      );
    }

    if (_selectedAnswer == null) {
      return null;
    }
    final shouldShowButton =
        widget.mode == QuizMode.learning || !_selectedAnswer!.isCorrect;
    if (!shouldShowButton) {
      return null;
    }
    return _FloatingBottomButton(
      label: nextLabel,
      onPressed: _goToNextStep,
      autoProgress: autoProgressValue,
      helperText: helperText,
    );
  }

  Widget _buildMultipleChoiceQuestion(
    BuildContext context,
    QuizQuestion question,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isLearningMode = widget.mode == QuizMode.learning;
    Widget? explanationSection;
    if (isLearningMode && _selectedAnswer != null) {
      final explanationText = _resolveExplanation(
        question: question,
        selectedAnswer: _selectedAnswer,
      );
      if (explanationText != null) {
        explanationSection = _ExplanationCard(
          text: explanationText,
        );
      }
    }
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
        if (_shouldShowIDontKnowButton(question)) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _handleIDontKnow(question),
              child: Text(l10n.quizButtonIDontKnow),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (explanationSection != null) ...[
          explanationSection,
        ] else if (_selectedAnswer != null && !_selectedAnswer!.isCorrect) ...[
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
        ],
      ],
    );
  }

  Widget _buildOpenQuestion(BuildContext context, QuizQuestion question) {
    final l10n = AppLocalizations.of(context)!;
    final isLearningMode = widget.mode == QuizMode.learning;
    Widget? explanationSection;
    if (isLearningMode && _openAnswerCorrect != null) {
      final explanationText = _resolveExplanation(
        question: question,
        openAnswerCorrect: _openAnswerCorrect,
      );
      if (explanationText != null) {
        explanationSection = _ExplanationCard(
          text: explanationText,
        );
      }
    }
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
        if (_openAnswerCorrect == null)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _submitOpenAnswer(question),
              child: Text(l10n.quizButtonCheckAnswer),
            ),
          ),
        if (_shouldShowIDontKnowButton(question)) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _handleIDontKnow(question),
              child: Text(l10n.quizButtonIDontKnow),
            ),
          ),
        ],
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
        if (explanationSection != null) ...[
          const SizedBox(height: 16),
          explanationSection,
        ],
      ],
    );
  }

  bool _shouldShowIDontKnowButton(QuizQuestion question) {
    if (widget.mode != QuizMode.learning) return false;
    if (question.isOpen) {
      return _openAnswerCorrect == null;
    }
    return _selectedAnswer == null;
  }

  String? _resolveExplanation({
    required QuizQuestion question,
    QuizAnswer? selectedAnswer,
    bool? openAnswerCorrect,
  }) {
    final explanations = question.explanations;
    if (explanations.isEmpty) {
      return null;
    }
    final answerCountForExplanation = question.isOpen
        ? question.acceptedAnswers.length
        : question.answers.length;

    if (_usedIDontKnow) {
      return explanations.last;
    }
    if (selectedAnswer != null) {
      final answerIndex = question.answers.indexOf(selectedAnswer);
      if (answerIndex >= 0) {
        final mappedIndex = _answerExplanationIndex(
          attemptIndex: answerIndex,
          answersCount: answerCountForExplanation,
          explanationsLength: explanations.length,
        );
        if (mappedIndex >= 0 && mappedIndex < explanations.length) {
          return explanations[mappedIndex];
        }
      }
    }
    if (question.isOpen && openAnswerCorrect == true) {
      final matchedIndex = _lastMatchedOpenAnswerIndex ?? 0;
      final mappedIndex = _answerExplanationIndex(
        attemptIndex: matchedIndex,
        answersCount: answerCountForExplanation,
        explanationsLength: explanations.length,
      );
      if (mappedIndex >= 0 && mappedIndex < explanations.length) {
        return explanations[mappedIndex];
      }
    }
    return null;
  }

  int _answerExplanationIndex({
    required int attemptIndex,
    required int answersCount,
    required int explanationsLength,
  }) {
    if (explanationsLength == 0) return -1;
    var maxIndexForAnswers = explanationsLength - 1;
    if (answersCount > 0 && explanationsLength > answersCount) {
      maxIndexForAnswers = explanationsLength - 2;
    }
    if (maxIndexForAnswers < 0) {
      maxIndexForAnswers = 0;
    }
    if (attemptIndex < 0) return 0;
    if (attemptIndex > maxIndexForAnswers) {
      return maxIndexForAnswers;
    }
    return attemptIndex;
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

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QuestionMarkdown(
            text: text,
            baseStyle: theme.textTheme.bodyLarge,
            bodyStyle: theme.textTheme.bodyMedium,
          ),
        ],
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
  const _QuestionMarkdown({
    required this.text,
    this.baseStyle,
    this.bodyStyle,
  });

  final String text;
  final TextStyle? baseStyle;
  final TextStyle? bodyStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = baseStyle ?? bodyStyle ?? theme.textTheme.bodyLarge;
    return GptMarkdown(
      _sanitizeEscapes(text),
      style: effectiveStyle,
      textAlign: TextAlign.start,
      textScaler: MediaQuery.textScalerOf(context),
      useDollarSignsForLatex: true,
      imageBuilder: (ctx, url) => _buildMarkdownImage(url),
    );
  }

  String _sanitizeEscapes(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '\\' && i + 1 < input.length) {
        final next = input[i + 1];
        if (_shouldUnescape(next)) {
          buffer.write(next);
          i++;
          continue;
        }
      }
      buffer.write(char);
    }
    final sanitized = buffer.toString();
    return _sanitizeOrderedListTriggers(sanitized);
  }

  bool _shouldUnescape(String next) {
    return next == '.';
  }

  String _sanitizeOrderedListTriggers(String input) {
    if (input.isEmpty) return input;
    final lines = input.split('\n');
    for (var i = 0; i < lines.length; i++) {
      lines[i] = _escapeOrderedListLine(lines[i]);
    }
    return lines.join('\n');
  }

  String _escapeOrderedListLine(String line) {
    final match = RegExp(r'^(\s*)(\d+)\.(\s+)').firstMatch(line);
    if (match == null) return line;
    final insertIndex = match.group(1)!.length + match.group(2)!.length;
    return '${line.substring(0, insertIndex)}\u200B${line.substring(insertIndex)}';
  }

  Widget _buildMarkdownImage(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }
    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      uri = null;
    }
    final isAsset = uri == null || uri.scheme.isEmpty || uri.scheme == 'asset';
    final path = uri == null
        ? trimmed
        : (uri.scheme == 'asset' || uri.scheme.isEmpty ? uri.path : trimmed);
    final image = isAsset
        ? Image.asset(path, fit: BoxFit.contain)
        : Image.network(trimmed, fit: BoxFit.contain);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: image,
    );
  }
}

class _FloatingBottomButton extends StatelessWidget {
  const _FloatingBottomButton({
    required this.label,
    required this.onPressed,
    this.autoProgress,
    this.helperText,
  });

  final String label;
  final VoidCallback onPressed;
  final double? autoProgress;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final buttonWidth = width > 32 ? width - 32 : width;
    final showProgress = autoProgress != null;
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showProgress) ...[
            SizedBox(
              width: buttonWidth,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: autoProgress!.clamp(0.0, 1.0),
                  minHeight: 4,
                ),
              ),
            ),
            if (helperText != null) ...[
              const SizedBox(height: 6),
              Text(
                helperText!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: buttonWidth,
            child: ElevatedButton(
              key: const Key('quizNextButton'),
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(label),
            ),
          ),
        ],
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
    List<String> explanations = const [],
  })  : answers = List.unmodifiable(answers),
        acceptedAnswers = List.unmodifiable(acceptedAnswers),
        explanations = List.unmodifiable(explanations);

  final int id;
  final String text;
  final QuizQuestionType type;
  final List<QuizAnswer> answers;
  final List<String> acceptedAnswers;
  final List<String> explanations;

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
    return acceptedAnswerIndexFor(response) != null;
  }

  int? acceptedAnswerIndexFor(String response) {
    if (!isOpen) return null;
    final normalizedAttempt = _normalizeAnswer(response);
    for (var i = 0; i < acceptedAnswers.length; i++) {
      final candidate = _normalizeAnswer(acceptedAnswers[i]);
      if (candidate == normalizedAttempt) {
        return i;
      }
    }
    return null;
  }

  factory QuizQuestion.fromMap(
    Map<String, dynamic> map, {
    required int id,
  }) {
    final questionText = (map['text'] ?? '').toString().trim();
    final type = _parseType(map['type']);
    final answersRaw = map['answers'];
    final explanations = _parseExplanationList(map['explanations']);
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
        explanations: explanations,
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
      explanations: explanations,
    );
  }

  static QuizQuestionType _parseType(Object? raw) {
    final value = raw?.toString().toLowerCase().trim();
    if (value == 'open' || value == 'text' || value == 'input') {
      return QuizQuestionType.open;
    }
    return QuizQuestionType.multipleChoice;
  }

  static const Map<String, String> _diacriticFold = <String, String>{
    'ą': 'a',
    'ć': 'c',
    'ę': 'e',
    'ł': 'l',
    'ń': 'n',
    'ó': 'o',
    'ś': 's',
    'ź': 'z',
    'ż': 'z',
  };
  static final RegExp _nonAlphanumeric = RegExp(r'[^a-z0-9]+');
  static final RegExp _multiWhitespace = RegExp(r'\s+');

  static String _normalizeAnswer(String value) {
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (final codePoint in lower.runes) {
      final char = String.fromCharCode(codePoint);
      buffer.write(_diacriticFold[char] ?? char);
    }
    return buffer
        .toString()
        .replaceAll(_nonAlphanumeric, ' ')
        .replaceAll(_multiWhitespace, ' ')
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

  static List<String> _parseExplanationList(Object? raw) {
    if (raw is Iterable) {
      final collected = <String>[];
      for (final entry in raw) {
        String? text;
        if (entry is String) {
          text = entry;
        } else if (entry is YamlScalar) {
          text = entry.value?.toString();
        }
        text = text?.trim();
        if (text != null && text.isNotEmpty) {
          collected.add(text);
        }
      }
      return collected;
    }
    return const [];
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
