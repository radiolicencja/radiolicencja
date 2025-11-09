import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'quiz.dart';

class TopicListScreen extends StatefulWidget {
  const TopicListScreen({super.key});

  @override
  State<TopicListScreen> createState() => _TopicListScreenState();
}

class _TopicListScreenState extends State<TopicListScreen> {
  late final Future<List<Topic>> _topicsFuture;

  @override
  void initState() {
    super.initState();
    _topicsFuture = TopicRepository.loadTopics();
  }

  void _handleTopicTap(BuildContext context, Topic topic) {
    if (!topic.hasQuestions) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This topic has no questions yet. Add some to begin.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          topicTitle: topic.title,
          questions: topic.questions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Topics'),
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
                  'Unable to load topics.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          final topics = snapshot.data ?? const <Topic>[];
          if (topics.isEmpty) {
            return const Center(
              child: Text('Add topic files to assets/topics to get started.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: topics.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final topic = topics[index];
              return TopicCard(
                topic: topic,
                onTap: () => _handleTopicTap(context, topic),
              );
            },
          );
        },
      ),
    );
  }
}

class TopicCard extends StatelessWidget {
  const TopicCard({super.key, required this.topic, this.onTap});

  final Topic topic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
                      topic.hasQuestions
                          ? '${topic.questions.length} questions'
                          : 'No questions yet',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
      for (final item in raw) {
        if (item is Map) {
          questions.add(
            QuizQuestion.fromMap(Map<String, dynamic>.from(item)),
          );
        } else if (item is YamlMap) {
          questions.add(
            QuizQuestion.fromMap(Map<String, dynamic>.from(item)),
          );
        }
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
