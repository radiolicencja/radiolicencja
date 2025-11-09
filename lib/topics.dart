import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'l10n/app_localizations.dart';
import 'quiz.dart';
import 'services/learning_progress.dart';

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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          topicSlug: topic.slug,
          topicTitle: topic.title,
          questions: topic.questions,
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
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: topics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final topic = topics[index];
              final totalQuestions = topic.questions.length;
              final masteredCount =
                  _progressService?.getMastered(topic.slug).length ?? 0;
              final progressLabel = !topic.hasQuestions
                  ? l10n.topicNoQuestions
                  : _progressService == null
                      ? l10n.topicQuestionCount(totalQuestions)
                      : l10n.topicProgress(masteredCount, totalQuestions);
              return TopicCard(
                topic: topic,
                progressLabel: progressLabel,
                canResetProgress:
                    _progressService != null && masteredCount > 0,
                onResetProgress: _progressService == null
                    ? null
                    : () => _confirmReset(topic),
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

class TopicCard extends StatelessWidget {
  const TopicCard({
    super.key,
    required this.topic,
    required this.progressLabel,
    this.canResetProgress = false,
    this.onResetProgress,
    this.onTap,
  });

  final Topic topic;
  final String progressLabel;
  final bool canResetProgress;
  final VoidCallback? onResetProgress;
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
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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

class Topic {
  const Topic({
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.slug,
    required this.questions,
  });

  final String title;
  final String description;
  final String imageAsset;
  final String slug;
  final List<QuizQuestion> questions;

  bool get hasQuestions => questions.isNotEmpty;

  factory Topic.fromMap(Map<String, dynamic> map) {
    final title = (map['title'] ?? '').toString().trim();
    return Topic(
      title: title.isEmpty ? 'Untitled topic' : title,
      description: (map['description'] ?? '').toString().trim(),
      imageAsset: (map['image'] ?? '').toString().trim(),
      slug: _slugify(map['slug'], fallback: title),
      questions: _parseQuestions(map['questions']),
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
