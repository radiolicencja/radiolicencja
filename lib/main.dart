import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Licencja',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const TopicListScreen(),
    );
  }
}

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
              return TopicCard(topic: topic);
            },
          );
        },
      ),
    );
  }
}

class TopicCard extends StatelessWidget {
  const TopicCard({super.key, required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
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
  });

  final String title;
  final String description;
  final String imageAsset;
  final String slug;

  factory Topic.fromMap(Map<String, dynamic> map) {
    final title = (map['title'] ?? '').toString().trim();
    return Topic(
      title: title.isEmpty ? 'Untitled topic' : title,
      description: (map['description'] ?? '').toString().trim(),
      imageAsset: (map['image'] ?? '').toString().trim(),
      slug: _slugify(map['slug'], fallback: title),
    );
  }

  static String _slugify(Object? value, {required String fallback}) {
    final raw = (value ?? '').toString().trim();
    if (raw.isNotEmpty) {
      return raw;
    }
    return fallback
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp('^-|-\$'), '');
  }
}

class TopicRepository {
  static const _topicsFolder = 'assets/topics/';

  static Future<List<Topic>> loadTopics() async {
    final manifestContent =
        await rootBundle.loadString('AssetManifest.json');
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
        }
      } catch (error) {
        debugPrint('Failed to parse $assetPath: $error');
      }
    }

    return topics;
  }
}
