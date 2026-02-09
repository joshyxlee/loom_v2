import 'package:flutter/material.dart';

import '../services/core_data_store.dart';
import '../models/pokedex_entry.dart';

class PokedexScreen extends StatelessWidget {
  const PokedexScreen({super.key, required this.coreDataStore});

  final CoreDataStore coreDataStore;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByStage(coreDataStore.pokedexEntries);
    return Scaffold(
      appBar: AppBar(title: const Text('圖鑑')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final stage in [1, 2, 3, 4]) ...[
            if (grouped[stage]?.isNotEmpty ?? false) ...[
              Text('Stage $stage',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...grouped[stage]!.map((entry) => _EntryCard(
                    entry: entry,
                    coreDataStore: coreDataStore,
                  )),
              const SizedBox(height: 16),
            ]
          ],
        ],
      ),
    );
  }

  Map<int, List<PokedexEntry>> _groupByStage(List<PokedexEntry> entries) {
    final sorted = List<PokedexEntry>.from(entries)
      ..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
    final map = <int, List<PokedexEntry>>{};
    for (final entry in sorted) {
      map.putIfAbsent(entry.petStage, () => []).add(entry);
    }
    return map;
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.coreDataStore});

  final PokedexEntry entry;
  final CoreDataStore coreDataStore;

  @override
  Widget build(BuildContext context) {
    final typeLabel = _resolveTypeLabel();
    final top3 = _resolveTop3Labels();
    final date = entry.unlockedAt.toIso8601String().split('T').first;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Type: $typeLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Top3: ${top3.join(', ')}'),
          const SizedBox(height: 4),
          Text('Bond ${entry.bondLevelAtUnlock}'),
          const SizedBox(height: 4),
          Text('Unlocked: $date', style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  String _resolveTypeLabel() {
    if (entry.petType != 'major') return 'Balanced';
    if (entry.creditSnapshotTop3.isEmpty) return 'Balanced';
    final top = entry.creditSnapshotTop3.first;
    final matches = coreDataStore.subjects.where((s) => s.subjectId == top.subjectId).toList();
    return matches.isNotEmpty ? matches.first.displayName : 'Unknown';
  }

  List<String> _resolveTop3Labels() {
    if (entry.creditSnapshotTop3.isEmpty) return ['Unknown'];
    final labels = <String>[];
    for (final item in entry.creditSnapshotTop3) {
      final matches = coreDataStore.subjects.where((s) => s.subjectId == item.subjectId).toList();
      labels.add(matches.isNotEmpty ? matches.first.displayName : 'Unknown');
    }
    return labels;
  }
}
