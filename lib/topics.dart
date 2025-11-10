import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:yaml/yaml.dart';

import 'l10n/app_localizations.dart';
import 'quiz.dart';
import 'services/learning_progress.dart';
import 'services/learning_question_picker.dart';

class TopicListScreen extends StatefulWidget {
  const TopicListScreen({super.key});

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  late final Future<List<Topic>> _topicsFuture;
  LearningProgressService? _progressService;

  @override
  void initState() {
    super.initState();
    _topicsFuture = TopicRepository.loadTopics();
    _initProgressService();
  }

  Future<void> _initProgressService() async {
    final service = await LearningProgressService.load();
    if (!mounted) return;
    setState(() {
      _progressService = service;
    });
  }

  Future<LearningProgressService?> _ensureProgressService() async {
    if (_progressService != null) {
      return _progressService;
    }
    final service = await LearningProgressService.load();
    if (!mounted) return null;
    setState(() {
      _progressService = service;
    });
    return service;
  }

  Future<void> _handleTopicTap(Topic topic) async {
    if (!topic.hasQuestions) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.topicNoQuestions),
        ),
      );
      return;
    }
    final progressService = await _ensureProgressService();
    if (!mounted || progressService == null) return;
    final l10n = AppLocalizations.of(context)!;
    final mode = await showModalBottomSheet<QuizMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.quiz_outlined),
                title: Text(l10n.modeSheetTestTitle),
                subtitle: Text(l10n.modeSheetTestSubtitle),
                onTap: () => Navigator.of(sheetContext).pop(QuizMode.test),
              ),
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text(l10n.modeSheetLearningTitle),
                subtitle: Text(l10n.modeSheetLearningSubtitle),
                onTap: () => Navigator.of(sheetContext).pop(QuizMode.learning),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (mode == null) return;
    if (!mounted) return;
    final questions = mode == QuizMode.test
        ? topic.buildTestQuestions()
        : topic.questions;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          topicSlug: topic.slug,
          topicTitle: topic.title,
          questions: questions,
          mode: mode,
          progressService: progressService,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _confirmReset(Topic topic) async {
    final service = await _ensureProgressService();
    if (!mounted || service == null) return;
    final l10n = AppLocalizations.of(context)!;
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.topicResetDialogTitle),
        content: Text(l10n.topicResetDialogBody(topic.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.topicResetDialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.topicResetDialogConfirm),
          ),
        ],
      ),
    );
    if (shouldReset == true) {
      await service.reset(topic.slug);
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _showTopicStats(Topic topic) async {
    final service = await _ensureProgressService();
    if (!mounted || service == null) return;
    final stats = service.getQuestionStats(topic.slug);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: TopicStatsSheet(
          topic: topic,
          stats: stats,
        ),
      ),
    );
  }

  double? _calculateTopicConfidence(
    Topic topic,
    Map<int, QuestionStats> stats,
  ) {
    if (topic.questions.isEmpty) return null;
    final picker = LearningQuestionPicker<QuizQuestion>(
      stats: stats,
      idResolver: (question) => question.id,
      random: Random(0),
    );
    var total = 0.0;
    for (final question in topic.questions) {
      total += picker.confidenceScore(question.id);
    }
    if (total.isNaN || total.isInfinite) {
      return null;
    }
    return total / topic.questions.length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.topicListTitle),
      ),
      body: FutureBuilder<List<Topic>>(
        future: _topicsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.topicLoadError('${snapshot.error ?? ''}'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          final topics = snapshot.data ?? const <Topic>[];
          if (topics.isEmpty) {
            return const Center(
              child: _EmptyTopicsMessage(),
            );
          }
          final items = topics.map((topic) {
            final totalQuestions = topic.questions.length;
            final masteredCount =
                _progressService?.getMastered(topic.slug).length ?? 0;
            bool hasStats = false;
            double? confidenceValue;
            String? confidenceLabel;
            if (_progressService != null) {
              final topicStats = _progressService!.getQuestionStats(topic.slug);
              hasStats = topicStats.isNotEmpty;
              final calculatedConfidence =
                  _calculateTopicConfidence(topic, topicStats);
              if (calculatedConfidence != null) {
                confidenceValue = calculatedConfidence;
                final percent =
                    (calculatedConfidence * 100).clamp(0, 100).round();
                confidenceLabel = l10n.topicConfidence(percent);
              }
            }
            final progressLabel = !topic.hasQuestions
                ? l10n.topicNoQuestions
                : _progressService == null
                    ? l10n.topicQuestionCount(totalQuestions)
                    : l10n.topicProgress(masteredCount, totalQuestions);
            return _TopicListItem(
              topic: topic,
              progressLabel: progressLabel,
              confidenceLabel: confidenceLabel,
              confidenceValue: confidenceValue,
              canResetProgress: _progressService != null &&
                  (masteredCount > 0 || hasStats),
            );
          }).toList();
          if (_progressService != null) {
            items.sort((a, b) {
              final aConfidence = a.confidenceValue ?? -1;
              final bConfidence = b.confidenceValue ?? -1;
              final cmp = bConfidence.compareTo(aConfidence);
              if (cmp != 0) return cmp;
              return a.topic.title.compareTo(b.topic.title);
            });
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final topic = item.topic;
              return TopicCard(
                topic: topic,
                progressLabel: item.progressLabel,
                confidenceLabel: item.confidenceLabel,
                canResetProgress: item.canResetProgress,
                onResetProgress: _progressService == null
                    ? null
                    : () => _confirmReset(topic),
                canShowStats: _progressService != null,
                onShowStats:
                    _progressService == null ? null : () => _showTopicStats(topic),
                onTap: () => _handleTopicTap(topic),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyTopicsMessage extends StatelessWidget {
  const _EmptyTopicsMessage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(l10n.topicListEmpty);
  }
}

class _TopicListItem {
  const _TopicListItem({
    required this.topic,
    required this.progressLabel,
    required this.canResetProgress,
    this.confidenceLabel,
    this.confidenceValue,
  });

  final Topic topic;
  final String progressLabel;
  final bool canResetProgress;
  final String? confidenceLabel;
  final double? confidenceValue;
}

class TopicCard extends StatelessWidget {
  const TopicCard({
    super.key,
    required this.topic,
    required this.progressLabel,
    this.confidenceLabel,
    this.canResetProgress = false,
    this.onResetProgress,
    this.canShowStats = false,
    this.onShowStats,
    this.onTap,
  });

  final Topic topic;
  final String progressLabel;
  final String? confidenceLabel;
  final bool canResetProgress;
  final VoidCallback? onResetProgress;
  final bool canShowStats;
  final VoidCallback? onShowStats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  topic.imageAsset,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topic.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progressLabel,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                    if (confidenceLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        confidenceLabel!,
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canShowStats)
                    IconButton(
                      icon: const Icon(Icons.bar_chart_outlined),
                      tooltip: l10n.topicStatsButtonLabel,
                      onPressed: onShowStats,
                    ),
                  if (canResetProgress)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: l10n.topicResetProgress,
                      onPressed: onResetProgress,
                    ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TopicStatsSheet extends StatelessWidget {
  const TopicStatsSheet({
    super.key,
    required this.topic,
    required this.stats,
  });

  final Topic topic;
  final Map<int, QuestionStats> stats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final picker = LearningQuestionPicker<QuizQuestion>(
      stats: stats,
      idResolver: (question) => question.id,
      random: Random(0),
    );
    final sortedQuestions = List<QuizQuestion>.from(topic.questions)
      ..sort((a, b) {
        final scoreA = picker.priorityScore(a.id);
        final scoreB = picker.priorityScore(b.id);
        final cmp = scoreB.compareTo(scoreA);
        if (cmp != 0) return cmp;
        return a.id.compareTo(b.id);
      });
    final totalCorrect =
        stats.values.fold<int>(0, (sum, stat) => sum + stat.correct);
    final totalIncorrect =
        stats.values.fold<int>(0, (sum, stat) => sum + stat.incorrect);
    final totalAnswered = totalCorrect + totalIncorrect;
    final summaryText = totalAnswered == 0
        ? l10n.topicStatsEmpty
        : l10n.topicStatsSummary(totalAnswered, totalCorrect, totalIncorrect);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.topicStatsTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              topic.title,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              summaryText,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: sortedQuestions.length,
                separatorBuilder: (_, __) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final question = sortedQuestions[index];
                  final questionStats = stats[question.id] ?? const QuestionStats();
                  final attempts = questionStats.totalAttempts;
                  final accuracy = attempts == 0
                      ? 0
                      : ((questionStats.correct / attempts) * 100).round();
                  final accuracyText = l10n.topicStatsAccuracy(
                    accuracy,
                    questionStats.correct,
                    attempts,
                  );
                  final lastSeenText = questionStats.lastSeen == null
                      ? l10n.topicStatsNeverSeen
                      : l10n.topicStatsLastSeen(
                          _formatTimestamp(context, questionStats.lastSeen!),
                        );
                  final correctAnswerText = _correctAnswerText(l10n, question);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: _StatsQuestionMarkdown(text: question.text),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(accuracyText),
                        Text(
                          lastSeenText,
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          l10n.topicStatsCorrectAnswer(correctAnswerText),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('✔ ${questionStats.correct}'),
                        Text('✖ ${questionStats.incorrect}'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(BuildContext context, DateTime dateTime) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final formatter = DateFormat.yMMMd(localeTag).add_Hm();
    return formatter.format(dateTime.toLocal());
  }

  String _correctAnswerText(AppLocalizations l10n, QuizQuestion question) {
    if (question.isOpen) {
      if (question.acceptedAnswers.isEmpty) {
        return l10n.topicStatsNoCorrectAnswer;
      }
      return question.acceptedAnswers.join(', ');
    }
    final answer = question.correctAnswer;
    final formatted = '${answer.label}. ${answer.text}'.trim();
    if (formatted.isEmpty) {
      return l10n.topicStatsNoCorrectAnswer;
    }
    return formatted;
  }
}

class _StatsQuestionMarkdown extends StatelessWidget {
  const _StatsQuestionMarkdown({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleMedium;
    final bodyStyle = theme.textTheme.bodyMedium;
    return MarkdownBody(
      data: text,
      shrinkWrap: true,
      listItemCrossAxisAlignment: MarkdownListItemCrossAxisAlignment.start,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: titleStyle,
        listBullet: bodyStyle,
        h1: titleStyle,
        h2: titleStyle,
        h3: titleStyle,
      ),
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
    );
  }
}

class Topic {
  const Topic({
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.slug,
    required this.questions,
    this.testQuestionLimit = 20,
  });

  final String title;
  final String description;
  final String imageAsset;
  final String slug;
  final List<QuizQuestion> questions;
  final int testQuestionLimit;

  bool get hasQuestions => questions.isNotEmpty;

  factory Topic.fromMap(Map<String, dynamic> map) {
    final title = (map['title'] ?? '').toString().trim();
    return Topic(
      title: title.isEmpty ? 'Untitled topic' : title,
      description: (map['description'] ?? '').toString().trim(),
      imageAsset: (map['image'] ?? '').toString().trim(),
      slug: _slugify(map['slug'], fallback: title),
      questions: _parseQuestions(map['questions']),
      testQuestionLimit: _parseTestLimit(map['test_question_limit']),
    );
  }

  static String _slugify(Object? value, {required String fallback}) {
    final raw = (value ?? '').toString().trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    final sanitized = fallback
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'(^-|-$)'), '');
    return sanitized.isEmpty ? 'topic' : sanitized;
  }

  static List<QuizQuestion> _parseQuestions(Object? raw) {
    if (raw is Iterable) {
      final questions = <QuizQuestion>[];
      var index = 0;
      for (final item in raw) {
        if (item is Map) {
          questions.add(
            QuizQuestion.fromMap(
              Map<String, dynamic>.from(item),
              id: index,
            ),
          );
        } else if (item is YamlMap) {
          questions.add(
            QuizQuestion.fromMap(
              Map<String, dynamic>.from(item),
              id: index,
            ),
          );
        }
        index++;
      }
      return questions;
    }
    return const [];
  }

  static int _parseTestLimit(Object? raw) {
    if (raw is int) {
      return raw > 0 ? raw : 20;
    }
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return 20;
  }

  List<QuizQuestion> buildTestQuestions({Random? random}) {
    final rng = random ?? Random();
    final pool = List<QuizQuestion>.from(questions)..shuffle(rng);
    final limit = testQuestionLimit <= 0 ? 20 : testQuestionLimit;
    if (pool.length <= limit) {
      return pool;
    }
    return pool.take(limit).toList();
  }
}

class TopicRepository {
  static const _topicsFolder = 'assets/topics/';

  static Future<List<Topic>> loadTopics() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final manifestMap =
        (jsonDecode(manifestContent) as Map<String, dynamic>);

    final topicAssets = manifestMap.keys
        .where(
          (assetPath) => assetPath.startsWith(_topicsFolder) &&
              assetPath.endsWith('.yaml'),
        )
        .toList()
      ..sort();

    final topics = <Topic>[];
    for (final assetPath in topicAssets) {
      try {
        final yamlString = await rootBundle.loadString(assetPath);
        final parsedYaml = loadYaml(yamlString);
        if (parsedYaml is YamlMap) {
          final map = Map<String, dynamic>.from(parsedYaml);
          topics.add(Topic.fromMap(map));
        } else if (parsedYaml is Map) {
          topics.add(Topic.fromMap(Map<String, dynamic>.from(parsedYaml)));
        }
      } catch (error) {
        debugPrint('Failed to parse $assetPath: $error');
      }
    }

    return topics;
  }
}
