import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Radio Licencja'**
  String get appTitle;

  /// No description provided for @topicListTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning Topics'**
  String get topicListTitle;

  /// Error shown when topics fail to load
  ///
  /// In en, this message translates to:
  /// **'Unable to load topics.\n{error}'**
  String topicLoadError(Object error);

  /// No description provided for @topicListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add topic files to assets/topics to get started.'**
  String get topicListEmpty;

  /// No description provided for @topicNoQuestions.
  ///
  /// In en, this message translates to:
  /// **'This topic has no questions yet. Add some to begin.'**
  String get topicNoQuestions;

  /// No description provided for @topicQuestionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {{count} question} other {{count} questions}}'**
  String topicQuestionCount(int count);

  /// No description provided for @topicProgress.
  ///
  /// In en, this message translates to:
  /// **'{mastered} / {total} learned'**
  String topicProgress(int mastered, int total);

  /// No description provided for @topicConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence {percent}%'**
  String topicConfidence(int percent);

  /// No description provided for @topicResetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset progress'**
  String get topicResetProgress;

  /// No description provided for @topicResetDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset learning progress?'**
  String get topicResetDialogTitle;

  /// No description provided for @topicResetDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This removes learned questions for {topic}.'**
  String topicResetDialogBody(Object topic);

  /// No description provided for @topicResetDialogConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get topicResetDialogConfirm;

  /// No description provided for @topicResetDialogCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get topicResetDialogCancel;

  /// No description provided for @topicStatsButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get topicStatsButtonLabel;

  /// No description provided for @topicStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning statistics'**
  String get topicStatsTitle;

  /// No description provided for @topicStatsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No answers recorded yet.'**
  String get topicStatsEmpty;

  /// No description provided for @topicStatsSummary.
  ///
  /// In en, this message translates to:
  /// **'Answered {answered} times ({correct} correct / {incorrect} incorrect)'**
  String topicStatsSummary(int answered, int correct, int incorrect);

  /// No description provided for @topicStatsAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy: {percent}% ({correct}/{total})'**
  String topicStatsAccuracy(int percent, int correct, int total);

  /// No description provided for @topicStatsLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen: {time}'**
  String topicStatsLastSeen(Object time);

  /// No description provided for @topicStatsNeverSeen.
  ///
  /// In en, this message translates to:
  /// **'Never seen yet'**
  String get topicStatsNeverSeen;

  /// No description provided for @topicStatsCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {answer}'**
  String topicStatsCorrectAnswer(Object answer);

  /// No description provided for @topicStatsNoCorrectAnswer.
  ///
  /// In en, this message translates to:
  /// **'Correct answer not provided'**
  String get topicStatsNoCorrectAnswer;

  /// No description provided for @modeSheetTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Take test'**
  String get modeSheetTestTitle;

  /// No description provided for @modeSheetTestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Standard quiz, questions asked once.'**
  String get modeSheetTestSubtitle;

  /// No description provided for @modeSheetLearningTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning mode'**
  String get modeSheetLearningTitle;

  /// No description provided for @modeSheetLearningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Retry incorrect questions until you master all.'**
  String get modeSheetLearningSubtitle;

  /// No description provided for @quizNoQuestionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No questions available for this topic yet.'**
  String get quizNoQuestionsAvailable;

  /// No description provided for @quizQuestionProgress.
  ///
  /// In en, this message translates to:
  /// **'Question {current} of {total}'**
  String quizQuestionProgress(Object current, Object total);

  /// No description provided for @quizLearningProgress.
  ///
  /// In en, this message translates to:
  /// **'Mastered {mastered} of {total}'**
  String quizLearningProgress(Object mastered, Object total);

  /// No description provided for @quizCorrectAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Correct answer: {label}. {answer}'**
  String quizCorrectAnswerLabel(Object label, Object answer);

  /// No description provided for @quizButtonSeeScore.
  ///
  /// In en, this message translates to:
  /// **'See score'**
  String get quizButtonSeeScore;

  /// No description provided for @quizButtonNextQuestion.
  ///
  /// In en, this message translates to:
  /// **'Next question'**
  String get quizButtonNextQuestion;

  /// No description provided for @quizButtonCheckAnswer.
  ///
  /// In en, this message translates to:
  /// **'Check answer'**
  String get quizButtonCheckAnswer;

  /// No description provided for @quizButtonCorrect.
  ///
  /// In en, this message translates to:
  /// **'Correct!'**
  String get quizButtonCorrect;

  /// No description provided for @quizButtonIDontKnow.
  ///
  /// In en, this message translates to:
  /// **'I don\'t know'**
  String get quizButtonIDontKnow;

  /// No description provided for @quizAcceptedAnswersLabel.
  ///
  /// In en, this message translates to:
  /// **'Accepted answers: {answers}'**
  String quizAcceptedAnswersLabel(Object answers);

  /// No description provided for @quizWrongAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Not quite right.'**
  String get quizWrongAnswerLabel;

  /// No description provided for @quizYourAnswerLabel.
  ///
  /// In en, this message translates to:
  /// **'Your answer'**
  String get quizYourAnswerLabel;

  /// No description provided for @quizAutoAdvanceHint.
  ///
  /// In en, this message translates to:
  /// **'Advancing in {seconds}s - tap anywhere to keep reading'**
  String quizAutoAdvanceHint(Object seconds);

  /// No description provided for @quizLearningCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Learning session complete!'**
  String get quizLearningCompleteTitle;

  /// No description provided for @quizTestCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Quiz complete!'**
  String get quizTestCompleteTitle;

  /// No description provided for @quizLearningCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'You mastered all {total} questions.'**
  String quizLearningCompleteBody(Object total);

  /// No description provided for @quizTestCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'You answered {score} of {total} correctly.'**
  String quizTestCompleteBody(Object score, Object total);

  /// No description provided for @quizBackToTopicsButton.
  ///
  /// In en, this message translates to:
  /// **'Back to topics'**
  String get quizBackToTopicsButton;

  /// No description provided for @aboutButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutButtonLabel;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Radio Licencja'**
  String get aboutTitle;

  /// No description provided for @aboutLead.
  ///
  /// In en, this message translates to:
  /// **'Radio Licencja is a lightweight study companion for the Polish amateur radio exam. It loads quizzes from YAML topics and offers both exam-style tests and a spaced-repetition learning mode.'**
  String get aboutLead;

  /// No description provided for @aboutSecondary.
  ///
  /// In en, this message translates to:
  /// **'Use it to revisit the whole question bank, drill weak spots with instant explanations, and track how your confidence grows over time.'**
  String get aboutSecondary;

  /// No description provided for @aboutAuthorLabel.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get aboutAuthorLabel;

  /// No description provided for @aboutAuthorCredit.
  ///
  /// In en, this message translates to:
  /// **'Created and maintained by mareksmi.'**
  String get aboutAuthorCredit;

  /// No description provided for @aboutWebsiteLabel.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get aboutWebsiteLabel;

  /// No description provided for @aboutWebsiteValue.
  ///
  /// In en, this message translates to:
  /// **'radiolicencja.pl'**
  String get aboutWebsiteValue;

  /// No description provided for @aboutEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get aboutEmailLabel;

  /// No description provided for @aboutEmailValue.
  ///
  /// In en, this message translates to:
  /// **'marek.smigielski@gmail.com'**
  String get aboutEmailValue;

  /// No description provided for @aboutLinkOpenError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open link. Copy and paste instead.'**
  String get aboutLinkOpenError;

  /// No description provided for @aboutDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Answer explanations are generated by AI and may contain errors. Please verify them yourself.'**
  String get aboutDisclaimer;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'pl': return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
