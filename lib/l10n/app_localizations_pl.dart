// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'Radio Licencja';

  @override
  String get topicListTitle => 'Tematy nauki';

  @override
  String topicLoadError(Object error) {
    return 'Nie udało się wczytać tematów.\n$error';
  }

  @override
  String get topicListEmpty => 'Dodaj pliki tematów do assets/topics, aby rozpocząć.';

  @override
  String get topicNoQuestions => 'Ten temat nie ma jeszcze pytań. Dodaj je, aby zacząć.';

  @override
  String topicQuestionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pytań',
      few: '$count pytania',
      one: '$count pytanie',
    );
    return '$_temp0';
  }

  @override
  String topicProgress(int mastered, int total) {
    return 'Opanowano $mastered z $total';
  }

  @override
  String get topicResetProgress => 'Wyzeruj postęp';

  @override
  String get topicResetDialogTitle => 'Wyzerować postęp?';

  @override
  String topicResetDialogBody(Object topic) {
    return 'To usunie opanowane pytania dla tematu $topic.';
  }

  @override
  String get topicResetDialogConfirm => 'Wyzeruj';

  @override
  String get topicResetDialogCancel => 'Anuluj';

  @override
  String get modeSheetTestTitle => 'Test';

  @override
  String get modeSheetTestSubtitle => 'Standardowy quiz, pytania tylko raz.';

  @override
  String get modeSheetLearningTitle => 'Tryb nauki';

  @override
  String get modeSheetLearningSubtitle => 'Powtarzaj błędne pytania, aż wszystkie opanujesz.';

  @override
  String get quizNoQuestionsAvailable => 'Brak pytań dla tego tematu.';

  @override
  String quizQuestionProgress(Object current, Object total) {
    return 'Pytanie $current z $total';
  }

  @override
  String quizLearningProgress(Object mastered, Object total) {
    return 'Opanowano $mastered z $total';
  }

  @override
  String quizCorrectAnswerLabel(Object label, Object answer) {
    return 'Poprawna odpowiedź: $label. $answer';
  }

  @override
  String get quizButtonSeeScore => 'Zobacz wynik';

  @override
  String get quizButtonNextQuestion => 'Następne pytanie';

  @override
  String get quizButtonCheckAnswer => 'Sprawdź odpowiedź';

  @override
  String get quizButtonCorrect => 'Poprawnie!';

  @override
  String get quizButtonIDontKnow => 'Nie wiem';

  @override
  String quizAcceptedAnswersLabel(Object answers) {
    return 'Akceptowane odpowiedzi: $answers';
  }

  @override
  String get quizWrongAnswerLabel => 'To nie to.';

  @override
  String get quizYourAnswerLabel => 'Twoja odpowiedź';

  @override
  String get quizLearningCompleteTitle => 'Zakończono naukę!';

  @override
  String get quizTestCompleteTitle => 'Koniec quizu!';

  @override
  String quizLearningCompleteBody(Object total) {
    return 'Opanowałeś wszystkie $total pytania.';
  }

  @override
  String quizTestCompleteBody(Object score, Object total) {
    return 'Odpowiedziałeś poprawnie na $score z $total.';
  }

  @override
  String get quizBackToTopicsButton => 'Wróć do tematów';
}
