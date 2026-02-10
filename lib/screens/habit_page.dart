import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_card.dart';
import '../theme/glass_theme.dart';
import '../models/habit.dart';

class HabitPage extends ConsumerStatefulWidget {
  const HabitPage({super.key});

  @override
  ConsumerState<HabitPage> createState() => _HabitPageState();
}

class _HabitPageState extends ConsumerState<HabitPage> {
  Habit? _selectedHabit;

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsProvider);
    final logsAsync = ref.watch(habitLogsProvider);

    return Row(
      children: [
        // Left: Habit List
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Habit', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () => _showAddHabitDialog(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Header for Grid
                Row(
                  children: [
                    const Expanded(flex: 2, child: SizedBox()), // Name space
                    Expanded(
                      flex: 1, 
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: _getLast7Days().map((d) => 
                          Text(['S','M','T','W','T','F','S'][d.weekday % 7], style: const TextStyle(color: Colors.white38, fontSize: 10))
                        ).toList(),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: habitsAsync.when(
                    data: (habits) => ListView.builder(
                      itemCount: habits.length,
                      itemBuilder: (context, index) {
                        final habit = habits[index];
                        final logs = logsAsync.value?[habit.id] ?? [];
                        return _HabitItem(
                          habit: habit,
                          logs: logs,
                          isSelected: _selectedHabit?.id == habit.id,
                          onTap: () => setState(() => _selectedHabit = habit),
                          onToggle: (date) => ref.read(habitToggleProvider)(habit.id, date),
                        );
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right: Detail Panel
        if (_selectedHabit != null) ...[
          const VerticalDivider(width: 1, color: Colors.white10),
          Expanded(
            flex: 2,
            child: _HabitDetailPanel(
              habit: _selectedHabit!,
              logs: logsAsync.value?[_selectedHabit!.id] ?? [],
              onClose: () => setState(() => _selectedHabit = null),
               onDelete: () {
                 ref.read(habitsProvider.notifier).deleteHabit(_selectedHabit!.id);
                 setState(() => _selectedHabit = null);
              },
            ),
          ),
        ],
      ],
    );
  }
  
  List<DateTime> _getLast7Days() {
    final today = DateTime.now();
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  Future<void> _showAddHabitDialog(BuildContext context, WidgetRef ref) async {
     final controller = TextEditingController();
     await showDialog(
       context: context,
       builder: (context) => AlertDialog(
         backgroundColor: const Color(0xFF1E1E1E),
         title: const Text('New Habit', style: TextStyle(color: Colors.white)),
         content: TextField(
           controller: controller,
           style: const TextStyle(color: Colors.white),
           decoration: const InputDecoration(hintText: 'Habit Name', hintStyle: TextStyle(color: Colors.white54)),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
           TextButton(onPressed: () {
             if (controller.text.isNotEmpty) {
                ref.read(habitsProvider.notifier).createHabit(controller.text);
                Navigator.pop(context);
             }
           }, child: const Text('Create')),
         ],
       ),
     );
  }
}

class _HabitItem extends StatelessWidget {
  final Habit habit;
  final List<DateTime> logs;
  final bool isSelected;
  final VoidCallback onTap;
  final Function(DateTime) onToggle;

  const _HabitItem({
    required this.habit,
    required this.logs,
    required this.isSelected,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final streak = _calculateStreak(logs, today);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? GlassTheme.accentColor.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? GlassTheme.accentColor.withValues(alpha: 0.3) : Colors.transparent),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (habit.color != null ? Color(int.parse(habit.color!.replaceAll('#','0xFF'))) : Colors.blue).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline, color: habit.color != null ? Color(int.parse(habit.color!.replaceAll('#','0xFF'))) : Colors.blue, size: 20),
            ),
            const SizedBox(width: 12),
            
            // Name & Streak
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text('$streak Day Streak', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),

            // Last 7 Days Grid
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (i) {
                  final d = DateTime.now().subtract(Duration(days: 6 - i));
                  final normalized = DateTime(d.year, d.month, d.day);
                  final isDone = logs.any((log) => log.isAtSameMomentAs(normalized));
                  
                  return GestureDetector(
                    onTap: () => onToggle(normalized),
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? Colors.white : Colors.white10,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateStreak(List<DateTime> logs, DateTime today) {
    // Simple streak logic
    if (logs.isEmpty) return 0;
    // Create a copy and sort descending
    final sortedLogs = List<DateTime>.from(logs)..sort((a, b) => b.compareTo(a));
    
    int streak = 0;
    DateTime check = today;
    
    // If not completed today, check if completed yesterday to maintain streak
    if (!sortedLogs.any((d) => d.isAtSameMomentAs(today))) {
      check = today.subtract(const Duration(days: 1));
    }

    while (sortedLogs.any((d) => d.isAtSameMomentAs(check))) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class _HabitDetailPanel extends StatelessWidget {
  final Habit habit;
  final List<DateTime> logs;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  const _HabitDetailPanel({required this.habit, required this.logs, required this.onClose, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final totalCheckIns = logs.length;
    final currentMonth = DateTime.now();
    final monthlyCheckIns = logs.where((d) => d.month == currentMonth.month && d.year == currentMonth.year).length;

    return Container(
      color: const Color(0xFF161616),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: onClose),
                const Spacer(),
                IconButton(icon: const Icon(Icons.delete, color: Colors.white54), onPressed: onDelete),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.blue, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Text(habit.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Stats Grid
                  Row(
                    children: [
                      Expanded(child: _StatCard(label: "Monthly check-ins", value: "$monthlyCheckIns", sub: "Day")),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(label: "Total Check-Ins", value: "$totalCheckIns", sub: "Days")),
                    ],
                  ),
                  const SizedBox(height: 12),
                   Row(
                    children: [
                      Expanded(child: _StatCard(label: "Monthly completion", value: "$monthlyCheckIns", sub: "Count")),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(label: "Current Streak", value: "TODO", sub: "Day")),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Calendar
                  const Text("February 2026", style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 16),
                  GlassCard(
                    padding: const EdgeInsets.all(8),
                    child: TableCalendar(
                      firstDay: DateTime(2020),
                      lastDay: DateTime(2030),
                      focusedDay: DateTime.now(),
                      calendarFormat: CalendarFormat.month,
                      headerVisible: false,
                      daysOfWeekStyle: const DaysOfWeekStyle(weekdayStyle: TextStyle(color: Colors.white38), weekendStyle: TextStyle(color: Colors.white38)),
                      calendarStyle: const CalendarStyle(
                        defaultTextStyle: TextStyle(color: Colors.white),
                        weekendTextStyle: TextStyle(color: Colors.white),
                        outsideTextStyle: TextStyle(color: Colors.white10),
                        todayDecoration: BoxDecoration(color: Colors.transparent, shape: BoxShape.circle), // Handle manually
                        selectedDecoration: BoxDecoration(color: Colors.transparent),
                      ),
                      calendarBuilders: CalendarBuilders(
                         defaultBuilder: (context, day, focusedDay) {
                           final normalized = DateTime(day.year, day.month, day.day);
                           final isDone = logs.any((d) => d.isAtSameMomentAs(normalized));
                           return Center(
                             child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDone ? Colors.white24 : Colors.transparent,
                                ),
                                child: Center(child: Text('${day.day}', style: TextStyle(color: isDone ? Colors.white : Colors.white38))),
                             ),
                           );
                         },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  const _StatCard({required this.label, required this.value, required this.sub});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Row(children: [
             const Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
             const SizedBox(width: 6),
             Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
           ]),
           const SizedBox(height: 8),
           RichText(text: TextSpan(
             children: [
               TextSpan(text: value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
               TextSpan(text: " $sub", style: const TextStyle(color: Colors.white38, fontSize: 12)),
             ]
           )),
        ],
      ),
    );
  }
}
