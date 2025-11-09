import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

enum QuizQuestionType { multipleChoice, open }

class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.topicTitle,
    required this.questions,
  });

  final String topicTitle;
  final List<QuizQuestion> questions;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQuestion> _questions;
  int _currentQuestionIndex = 0;
  int _score = 0;
  QuizAnswer? _selectedAnswer;
  bool _showSummary = false;
  bool? _openAnswerCorrect;
  final TextEditingController _openAnswerController = TextEditingController();
  final FocusNode _openAnswerFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _questions = List<QuizQuestion>.from(widget.questions)..shuffle();
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
    setState(() {
      _selectedAnswer = answer;
      if (answer.isCorrect) {
        _score++;
      }
    });
    if (answer.isCorrect) {
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
      _openAnswerFocus.unfocus();
      _scheduleAdvanceAfterCorrect(questionIndex);
    }
  }

  void _goToNextStep() {
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

  void _scheduleAdvanceAfterCorrect(int questionIndex) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _showSummary) return;
      if (_currentQuestionIndex != questionIndex) return;
      _goToNextStep();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.topicTitle)),
        body: const Center(
          child: Text('No questions available for this topic yet.'),
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

  Widget _buildQuestionView(BuildContext context) {
    final question = _questions[_currentQuestionIndex];
    final commonHeader = <Widget>[
      Text(
        'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Colors.grey[600]),
      ),
      const SizedBox(height: 12),
      Text(
        question.text,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
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
            'Correct answer: ${question.correctAnswer.label}. ${question.correctAnswer.text}',
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
              child: Text(
                _currentQuestionIndex == _questions.length - 1
                    ? 'See score'
                    : 'Next question',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOpenQuestion(BuildContext context, QuizQuestion question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _openAnswerController,
          focusNode: _openAnswerFocus,
          enabled: _openAnswerCorrect == null,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Your answer',
          ),
          onSubmitted: (_) => _submitOpenAnswer(question),
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
                  ? 'Check answer'
                  : (_openAnswerCorrect!
                      ? 'Correct!'
                      : _currentQuestionIndex == _questions.length - 1
                          ? 'See score'
                          : 'Next question'),
            ),
          ),
        ),
        if (_openAnswerCorrect == false) ...[
          const SizedBox(height: 16),
          Text(
            'Not quite right.',
            style:
                Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.red),
          ),
          const SizedBox(height: 8),
          Text(
            'Accepted answers: ${question.acceptedAnswers.join(', ')}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
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
          'Quiz complete!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'You answered $_score of ${_questions.length} correctly.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to topics'),
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

class QuizQuestion {
  QuizQuestion({
    required this.text,
    required this.type,
    List<QuizAnswer> answers = const [],
    List<String> acceptedAnswers = const [],
  })  : answers = List.unmodifiable(answers),
        acceptedAnswers = List.unmodifiable(acceptedAnswers);

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

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
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
