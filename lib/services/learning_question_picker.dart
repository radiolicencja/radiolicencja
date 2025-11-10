import 'dart:math';

import 'learning_progress.dart';

typedef QuestionIdResolver<T> = int Function(T item);

/// Orders questions for learning sessions using a lightweight spaced-repetition
/// heuristic:
///
/// * **Error-driven priority** – items with more incorrect answers get bumped
///   to the front so we reinforce weak spots quickly.
/// * **Mastery de-emphasis** – lots of correct answers lower the priority so
///   mastered material shows up less often (akin to the Leitner system).
/// * **Spacing effect** – questions not seen recently earn a positive recency
///   boost, while items surfaced seconds ago get a temporary penalty so we avoid
///   hammering the same card repeatedly in quick succession.
/// * **Stable randomness** – ties are resolved with deterministic random values
///   so the order still feels varied without changing between rebuilds.
///
/// Centralizing this logic keeps the learning strategy explicit and makes it
/// trivial to tweak or unit-test in isolation.
class LearningQuestionPicker<T> {
  LearningQuestionPicker({
    required Map<int, QuestionStats> stats,
    required QuestionIdResolver<T> idResolver,
    Random? random,
  })  : _stats = stats,
        _idResolver = idResolver,
        _random = random ?? Random();

  final Map<int, QuestionStats> _stats;
  final QuestionIdResolver<T> _idResolver;
  final Random _random;
  final Map<int, double> _tieBreakers = <int, double>{};
  DateTime _sortReference = DateTime.now();

  static const double _incorrectWeight = 5;
  static const double _correctWeight = 0.75;
  static const double _recencyCapHours = 72;
  static const double _neverSeenBoost = 96;
  static const double _recentPenaltyWindowHours = 0.25; // ~15 minutes
  static const double _recentPenaltyStrength = 15;
  static const double _confidenceMidpoint = 20;
  static const double _confidenceScale = 25;

  void sort(List<T> items) {
    _sortReference = DateTime.now();
    items.sort(_compare);
  }

  double priorityScore(int questionId) {
    return _priorityForQuestion(questionId);
  }

  /// Normalized inverse of [priorityScore] that approximates "mastery confidence"
  /// for display purposes.
  ///
  /// * High priority (many mistakes or never seen) -> confidence tends to 0.
  /// * Low/negative priority (lots of correct answers, recently drilled) -> confidence tends to 1.
  double confidenceScore(int questionId) {
    final score = _priorityForQuestion(questionId);
    final weakness =
        1 / (1 + exp(-(score - _confidenceMidpoint) / _confidenceScale));
    final confidence = 1 - weakness;
    if (!confidence.isFinite) {
      return 0.5;
    }
    if (confidence <= 0) {
      return 0;
    }
    if (confidence >= 1) {
      return 1;
    }
    return confidence;
  }

  int _compare(T a, T b) {
    final aId = _idResolver(a);
    final bId = _idResolver(b);
    final aScore = priorityScore(aId);
    final bScore = priorityScore(bId);
    if (aScore != bScore) {
      return bScore.compareTo(aScore);
    }
    final aTie = _tieBreakerForQuestion(aId);
    final bTie = _tieBreakerForQuestion(bId);
    return bTie.compareTo(aTie);
  }

  double _tieBreakerForQuestion(int id) {
    return _tieBreakers.putIfAbsent(id, () => _random.nextDouble());
  }

  double _priorityForQuestion(int id) {
    final stats = _stats[id];
    final incorrectScore = (stats?.incorrect ?? 0) * _incorrectWeight;
    final correctScore = (stats?.correct ?? 0) * _correctWeight;
    final recencyScore = _recencyBoost(stats?.lastSeen);
    return incorrectScore + recencyScore - correctScore;
  }

  double _recencyBoost(DateTime? lastSeen) {
    if (lastSeen == null) {
      return _neverSeenBoost;
    }
    final hoursSince =
        _sortReference.difference(lastSeen).inSeconds / Duration.secondsPerHour;
    if (hoursSince.isInfinite || hoursSince.isNaN) {
      return 0;
    }
    if (hoursSince < _recentPenaltyWindowHours) {
      final closeness =
          1 - (hoursSince / _recentPenaltyWindowHours).clamp(0, 1);
      return -_recentPenaltyStrength * closeness;
    }
    return hoursSince.clamp(0, _recencyCapHours);
  }
}
