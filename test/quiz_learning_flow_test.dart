import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:radiolicencja/l10n/app_localizations.dart';
import 'package:radiolicencja/quiz.dart';
import 'package:radiolicencja/services/learning_progress.dart';

const _nextButtonKey = Key('quizNextButton');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuizScreen learning mode', () {
    testWidgets(
      're-queues incorrectly answered question and accepts a later correct answer',
      (tester) async {
        final questions = <QuizQuestion>[
          _multipleChoiceQuestion(
            id: 0,
            text: 'Question 1',
            answers: [
              _answer('A', 'Incorrect 1', isCorrect: false),
              _answer('B', 'Correct 1', isCorrect: true),
              _answer('C', 'Also incorrect 1', isCorrect: false),
            ],
          ),
          _multipleChoiceQuestion(
            id: 1,
            text: 'Question 2',
            answers: [
              _answer('A', 'Incorrect 2', isCorrect: false),
              _answer('B', 'Correct 2', isCorrect: true),
              _answer('C', 'Also incorrect 2', isCorrect: false),
            ],
          ),
          _multipleChoiceQuestion(
            id: 2,
            text: 'Question 3',
            answers: [
              _answer('A', 'Incorrect 3', isCorrect: false),
              _answer('B', 'Also incorrect 3', isCorrect: false),
              _answer('C', 'Correct 3', isCorrect: true),
            ],
          ),
        ];

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final progressService = await LearningProgressService.load();
        const topicSlug = 'sample-topic';
        await _seedIncorrectStats(progressService, topicSlug);

        await tester.pumpWidget(
          _buildQuizApp(
            QuizScreen(
              topicSlug: topicSlug,
              topicTitle: 'Sample Topic',
              questions: questions,
              mode: QuizMode.learning,
              progressService: progressService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Start on question 1 with no mastered items yet.
        expect(find.text('Question 1'), findsOneWidget);
        expect(find.text('Mastered 0 of 3'), findsOneWidget);

        // Answer the first question correctly.
        await tester.tap(find.text('B. Correct 1'));
        await tester.pump();
        expect(find.text('Mastered 1 of 3'), findsOneWidget);

        // Move to the next question.
        await _tapNextButton(tester);

        // Question 2 should now be visible.
        expect(find.text('Question 2'), findsOneWidget);
        await tester.tap(find.text('A. Incorrect 2'));
        await tester.pump();
        expect(find.text('Mastered 1 of 3'), findsOneWidget);

        await _tapNextButton(tester);

        // Question 3 sequence.
        expect(find.text('Question 3'), findsOneWidget);
        await tester.tap(find.text('C. Correct 3'));
        await tester.pump();
        expect(find.text('Mastered 2 of 3'), findsOneWidget);

        await _tapNextButton(tester);

        // The originally failed Question 2 should reappear from the learning queue.
        expect(find.text('Question 2'), findsOneWidget);
        await tester.tap(find.text('B. Correct 2'));
        await tester.pump();
        expect(find.text('Mastered 3 of 3'), findsOneWidget);
      },
    );
  });
}

Widget _buildQuizApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

QuizQuestion _multipleChoiceQuestion({
  required int id,
  required String text,
  required List<QuizAnswer> answers,
}) {
  return QuizQuestion(
    id: id,
    text: text,
    type: QuizQuestionType.multipleChoice,
    answers: answers,
    explanations: const [],
  );
}

QuizAnswer _answer(String label, String text, {required bool isCorrect}) {
  return QuizAnswer(
    label: label,
    text: text,
    isCorrect: isCorrect,
  );
}

Future<void> _seedIncorrectStats(
  LearningProgressService service,
  String slug,
) async {
  final incorrectCounts = <int>[3, 2, 1];
  for (var questionId = 0; questionId < incorrectCounts.length; questionId++) {
    for (var i = 0; i < incorrectCounts[questionId]; i++) {
      await service.recordAnswerResult(slug, questionId, isCorrect: false);
    }
  }
}

Future<void> _tapNextButton(WidgetTester tester) async {
  final finder = find.byKey(_nextButtonKey);
  final button = tester.widget<ElevatedButton>(finder);
  button.onPressed?.call();
  await tester.pumpAndSettle();
}
