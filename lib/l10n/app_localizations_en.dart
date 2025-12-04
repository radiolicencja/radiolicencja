// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Radio Licencja';

  @override
  String get topicListTitle => 'Learning Topics';

  @override
  String topicLoadError(Object error) {
    return 'Unable to load topics.\n$error';
  }

  @override
  String get topicListEmpty => 'Add topic files to assets/topics to get started.';

  @override
  String get topicNoQuestions => 'This topic has no questions yet. Add some to begin.';

  @override
  String topicQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '$count question',
    );
    return '$_temp0';
  }

  @override
  String topicProgress(int mastered, int total) {
    return '$mastered / $total learned';
  }

  @override
  String topicConfidence(int percent) {
    return 'Confidence $percent%';
  }

  @override
  String get topicResetProgress => 'Reset progress';

  @override
  String get topicResetDialogTitle => 'Reset learning progress?';

  @override
  String topicResetDialogBody(Object topic) {
    return 'This removes learned questions for $topic.';
  }

  @override
  String get topicResetDialogConfirm => 'Reset';

  @override
  String get topicResetDialogCancel => 'Cancel';

  @override
  String get topicStatsButtonLabel => 'Statistics';

  @override
  String get topicStatsTitle => 'Learning statistics';

  @override
  String get topicStatsEmpty => 'No answers recorded yet.';

  @override
  String topicStatsSummary(int answered, int correct, int incorrect) {
    return 'Answered $answered times ($correct correct / $incorrect incorrect)';
  }

  @override
  String topicStatsAccuracy(int percent, int correct, int total) {
    return 'Accuracy: $percent% ($correct/$total)';
  }

  @override
  String topicStatsLastSeen(Object time) {
    return 'Last seen: $time';
  }

  @override
  String get topicStatsNeverSeen => 'Never seen yet';

  @override
  String topicStatsCorrectAnswer(Object answer) {
    return 'Correct answer: $answer';
  }

  @override
  String get topicStatsNoCorrectAnswer => 'Correct answer not provided';

  @override
  String get modeSheetTestTitle => 'Take test';

  @override
  String get modeSheetTestSubtitle => 'Standard quiz, questions asked once.';

  @override
  String get modeSheetLearningTitle => 'Learning mode';

  @override
  String get modeSheetLearningSubtitle => 'Retry incorrect questions until you master all.';

  @override
  String get quizNoQuestionsAvailable => 'No questions available for this topic yet.';

  @override
  String quizQuestionProgress(Object current, Object total) {
    return 'Question $current of $total';
  }

  @override
  String quizLearningProgress(Object mastered, Object total) {
    return 'Mastered $mastered of $total';
  }

  @override
  String quizCorrectAnswerLabel(Object label, Object answer) {
    return 'Correct answer: $label. $answer';
  }

  @override
  String get quizButtonSeeScore => 'See score';

  @override
  String get quizButtonNextQuestion => 'Next question';

  @override
  String get quizButtonCheckAnswer => 'Check answer';

  @override
  String get quizButtonCorrect => 'Correct!';

  @override
  String get quizButtonIDontKnow => 'I don\'t know';

  @override
  String quizAcceptedAnswersLabel(Object answers) {
    return 'Accepted answers: $answers';
  }

  @override
  String get quizWrongAnswerLabel => 'Not quite right.';

  @override
  String get quizYourAnswerLabel => 'Your answer';

  @override
  String quizAutoAdvanceHint(Object seconds) {
    return 'Advancing in ${seconds}s - tap anywhere to keep reading';
  }

  @override
  String get quizLearningCompleteTitle => 'Learning session complete!';

  @override
  String get quizTestCompleteTitle => 'Quiz complete!';

  @override
  String quizLearningCompleteBody(Object total) {
    return 'You mastered all $total questions.';
  }

  @override
  String quizTestCompleteBody(Object score, Object total) {
    return 'You answered $score of $total correctly.';
  }

  @override
  String get quizBackToTopicsButton => 'Back to topics';

  @override
  String get aboutButtonLabel => 'About';

  @override
  String get aboutTitle => 'About Radio Licencja';

  @override
  String get aboutLead => 'Radio Licencja is a lightweight study companion for the Polish amateur radio exam. It loads quizzes from YAML topics and offers both exam-style tests and a spaced-repetition learning mode.';

  @override
  String get aboutSecondary => 'Use it to revisit the whole question bank, drill weak spots with instant explanations, and track how your confidence grows over time.';

  @override
  String get aboutAuthorLabel => 'Author';

  @override
  String get aboutAuthorCredit => 'Created and maintained by SP7SMI (Marek Śmigielski).';

  @override
  String get aboutWebsiteLabel => 'Website';

  @override
  String get aboutWebsiteValue => 'https://radiolicencja.pl';

  @override
  String get aboutPrivacyLabel => 'Privacy policy';

  @override
  String get aboutPrivacyValue => 'https://radiolicencja.pl/promo/privacy-policy-en.html';

  @override
  String get aboutLinkOpenError => 'Couldn\'t open link. Copy and paste instead.';

  @override
  String get aboutDisclaimer => 'Answer explanations are generated by AI and may contain errors. Please verify them yourself.';
}
