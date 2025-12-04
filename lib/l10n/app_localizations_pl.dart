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
  String topicConfidence(int percent) {
    return 'Pewność $percent%';
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
  String get topicStatsButtonLabel => 'Statystyki';

  @override
  String get topicStatsTitle => 'Statystyki nauki';

  @override
  String get topicStatsEmpty => 'Brak zarejestrowanych odpowiedzi.';

  @override
  String topicStatsSummary(int answered, int correct, int incorrect) {
    return 'Odpowiedziano $answered razy ($correct poprawnie / $incorrect błędnie)';
  }

  @override
  String topicStatsAccuracy(int percent, int correct, int total) {
    return 'Skuteczność: $percent% ($correct/$total)';
  }

  @override
  String topicStatsLastSeen(Object time) {
    return 'Ostatnio widziane: $time';
  }

  @override
  String get topicStatsNeverSeen => 'Jeszcze nie wyświetlone';

  @override
  String topicStatsCorrectAnswer(Object answer) {
    return 'Poprawna odpowiedź: $answer';
  }

  @override
  String get topicStatsNoCorrectAnswer => 'Brak poprawnej odpowiedzi';

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
  String quizAutoAdvanceHint(Object seconds) {
    return 'Przechodzę dalej za ${seconds}s - stuknij, aby zatrzymać';
  }

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

  @override
  String get aboutButtonLabel => 'O aplikacji';

  @override
  String get aboutTitle => 'O Radio Licencja';

  @override
  String get aboutLead => 'Radio Licencja to lekki towarzysz nauki do polskiego egzaminu krótkofalarskiego. Wczytuje quizy z plików YAML i oferuje tryb testu oraz naukę opartą na powtórkach w czasie.';

  @override
  String get aboutSecondary => 'Wykorzystaj go do powtórek całej puli pytań, szybkiego utrwalania słabszych miejsc z wyjaśnieniami i obserwowania, jak rośnie Twoja pewność.';

  @override
  String get aboutAuthorLabel => 'Autor';

  @override
  String get aboutAuthorCredit => 'Twórca i opiekun: SP7SMI.';

  @override
  String get aboutWebsiteLabel => 'Strona';

  @override
  String get aboutWebsiteValue => 'https://radiolicencja.pl';

  @override
  String get aboutLinkOpenError => 'Nie udało się otworzyć linku. Skopiuj i wklej ręcznie.';

  @override
  String get aboutDisclaimer => 'Wyjaśnienia odpowiedzi generuje AI i mogą zawierać błędy. Zweryfikuj je samodzielnie.';
}
