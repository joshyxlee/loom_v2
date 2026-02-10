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
      body: grouped.isEmpty
          ? _EmptyState(onBack: () => Navigator.pop(context))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('最終成長',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...grouped[4]!.map((entry) => _EntryCard(
                      entry: entry,
                      coreDataStore: coreDataStore,
                    )),
              ],
            ),
    );
  }

  Map<int, List<PokedexEntry>> _groupByStage(List<PokedexEntry> entries) {
    final sorted = List<PokedexEntry>.from(entries)
      ..where((e) => e.petStage >= 4)
      ..sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
    if (sorted.isEmpty) return {};
    return {4: sorted};
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('你的圖鑑還是空的',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('現在還沒有收藏，是因為夥伴還沒第一次成長。',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center),
            const Text('等你走到第一次成長，就會出現第一筆收藏。',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('每個人的學習路線不同，留下的樣子也會不一樣。',
                style: TextStyle(color: Colors.black87),
                textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onBack,
              child: const Text('回去開始一回合'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
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
          Text(_learningNarrative(), style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('偏好：${top3.join(' / ')}', style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 6),
          Text('解鎖時間：$date', style: const TextStyle(color: Colors.black54)),
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

  String _learningNarrative() {
    if (entry.creditSnapshotTop3.isEmpty) return '你走的是平均路線。';
    final top = _resolveTop3Labels();
    if (top.length == 1) return '你明顯偏向 ${top.first} 的路線。';
    if (top.length == 2) return '你常在 ${top[0]} 和 ${top[1]} 之間游走。';
    return '你最常碰的是 ${top[0]}，也常走到 ${top[1]} 和 ${top[2]}。';
  }
}
