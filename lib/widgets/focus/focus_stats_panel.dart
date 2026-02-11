import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/app_providers.dart';
import '../../models/focus_session.dart';
import '../../models/task.dart';
import '../../models/habit.dart';
import '../../theme/glass_theme.dart';

class FocusStatsPanel extends ConsumerWidget {
  const FocusStatsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(focusHistoryProvider);
    final tasks = ref.watch(tasksProvider).asData?.value ?? [];
    final habits = ref.watch(habitsProvider).asData?.value ?? [];

    return Container(
      color: const Color(0xFF141414),
      padding: const EdgeInsets.all(24),
      child: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
        data: (history) {
          // Calculate Stats
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          final todaySessions = history.where((s) => s.startTime.isAfter(today)).toList();
          final todayPomo = todaySessions.length;
          final todayMinutes = todaySessions.fold(0, (sum, s) => sum + s.durationSeconds) ~/ 60;
          final totalPomo = history.length;
          final totalMinutes = history.fold(0, (sum, s) => sum + s.durationSeconds) ~/ 60;
          final totalHours = totalMinutes ~/ 60;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Overview', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              // Stats Grid
              Row(
                children: [
                  Expanded(child: _StatBox(label: "Today's Pomo", value: "$todayPomo")),
                  const SizedBox(width: 12),
                  Expanded(child: _StatBox(label: "Today's Focus", value: "${todayMinutes}m")),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _StatBox(label: "Total Pomo", value: "$totalPomo")),
                  const SizedBox(width: 12),
                  Expanded(child: _StatBox(label: "Total Duration", value: "${totalHours}h ${totalMinutes % 60}m")),
                ],
              ),

              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Focus Record', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.more_horiz, color: Colors.white54), onPressed: (){}),
                ],
              ),
              const SizedBox(height: 16),
              
              // Timeline
              Expanded(
                child: ListView(
                  children: _buildTimeline(history, tasks, habits),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildTimeline(List<FocusSession> sessions, List<Task> tasks, List<Habit> habits) {
    if (sessions.isEmpty) return [const Text("No records yet", style: TextStyle(color: Colors.white38))];

    final Map<String, List<FocusSession>> grouped = {};
    for (var s in sessions) {
      final dateKey = DateFormat('MMM d, yyyy').format(s.startTime);
      if (grouped[dateKey] == null) grouped[dateKey] = [];
      grouped[dateKey]!.add(s);
    }

    return grouped.entries.map((entry) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(entry.key, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          ...entry.value.map((session) {
            String title = "Focus Session";
            Color color = GlassTheme.accentColor;

            if (session.taskId != null) {
              final t = tasks.firstWhere((t) => t.id == session.taskId, orElse: () => Task(id: '', userId: '', title: 'Unknown Task'));
              title = t.title;
            } else if (session.habitId != null) {
              final h = habits.firstWhere((h) => h.id == session.habitId, orElse: () => Habit(id: '', userId: '', name: 'Unknown Habit', createdAt: DateTime.now()));
              title = h.name;
              color = Colors.purpleAccent;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 8),
              child: Row(
                children: [
                  // Timeline dot logic
                  Column(
                    children: [
                      Container(width: 2, height: 8, color: Colors.white10),
                      Icon(Icons.circle, size: 8, color: color),
                      Container(width: 2, height: 28, color: Colors.white10),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        Text(
                          "${DateFormat('HH:mm').format(session.startTime)} - ${DateFormat('HH:mm').format(session.endTime)}",
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${session.durationSeconds ~/ 60}m",
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }).toList();
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
