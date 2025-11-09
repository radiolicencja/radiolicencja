import 'package:shared_preferences/shared_preferences.dart';

class LearningProgressService {
  LearningProgressService._(this._prefs);

  final SharedPreferences _prefs;

  static const _keyPrefix = 'learning_progress_';

  static Future<LearningProgressService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LearningProgressService._(prefs);
  }

  Set<int> getMastered(String topicSlug) {
    final entries = _prefs.getStringList(_key(topicSlug)) ?? const [];
    return entries.map(int.parse).toSet();
  }

  Future<void> markMastered(String topicSlug, int questionId) async {
    final mastered = getMastered(topicSlug)..add(questionId);
    await _prefs.setStringList(
      _key(topicSlug),
      mastered.map((id) => id.toString()).toList(),
    );
  }

  Future<void> reset(String topicSlug) async {
    await _prefs.remove(_key(topicSlug));
  }

  String _key(String slug) => '$_keyPrefix$slug';
}
