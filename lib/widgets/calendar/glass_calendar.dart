import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/task.dart';
import '../../theme/glass_theme.dart';
import '../../providers/app_providers.dart';
import '../glass_card.dart';

class GlassCalendar extends ConsumerStatefulWidget {
  final Function(Task) onTaskTap;

  const GlassCalendar({super.key, required this.onTaskTap});

  @override
  ConsumerState<GlassCalendar> createState() => _GlassCalendarState();
}

class _GlassCalendarState extends ConsumerState<GlassCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final tasksMap = ref.watch(calendarTasksProvider);

    return Column(
      children: [
        GlassCard(
          padding: EdgeInsets.zero,
          child: TableCalendar<Task>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            eventLoader: (day) {
              final normalized = DateTime(day.year, day.month, day.day);
              return tasksMap[normalized] ?? [];
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            
            // Styles
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.white70),
              weekendStyle: TextStyle(color: Colors.white38),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: const TextStyle(color: Colors.white),
              weekendTextStyle: const TextStyle(color: Colors.white38),
              outsideTextStyle: const TextStyle(color: Colors.white12),
              todayDecoration: BoxDecoration(
                color: GlassTheme.accentColor.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: GlassTheme.accentColor,
                shape: BoxShape.circle,
              ),
              markerSize: 0, // We use custom builder
            ),
            
            // Interactivity
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },

            // Custom Builders
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return const SizedBox();
                
                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: events.take(4).map((task) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.0),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getPriorityColor(task.priority),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
              defaultBuilder: (context, day, focusedDay) {
                 return _buildCell(day, tasksMap);
              },
              todayBuilder: (context, day, focusedDay) {
                return _buildCell(day, tasksMap, isToday: true);
              },
              selectedBuilder: (context, day, focusedDay) {
                return _buildCell(day, tasksMap, isSelected: true);
              },
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Selected Day Task List
        Expanded(
          child: _selectedDay == null 
              ? const Center(child: Text("Select a day to view tasks", style: TextStyle(color: Colors.white38)))
              : _buildDayTaskList(tasksMap),
        ),
      ],
    );
  }

  Widget _buildCell(DateTime day, Map<DateTime, List<Task>> tasksMap, {bool isToday = false, bool isSelected = false}) {
    final normalized = DateTime(day.year, day.month, day.day);
    final tasks = tasksMap[normalized] ?? [];

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected 
            ? GlassTheme.accentColor 
            : (isToday ? GlassTheme.accentColor.withValues(alpha: 0.2) : Colors.transparent),
        borderRadius: BorderRadius.circular(8),
        border: isToday && !isSelected ? Border.all(color: GlassTheme.accentColor.withValues(alpha: 0.5)) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '${day.day}',
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          if (tasks.isNotEmpty)
            Column(
              children: tasks.take(3).map((task) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                  height: 3,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _getPriorityColor(task.priority),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildDayTaskList(Map<DateTime, List<Task>> tasksMap) {
    if (_selectedDay == null) return const SizedBox();
    final normalized = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final tasks = tasksMap[normalized] ?? [];

    if (tasks.isEmpty) {
      return const Center(child: Text("No tasks for this day", style: TextStyle(color: Colors.white38)));
    }

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => widget.onTaskTap(task),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: Colors.white.withValues(alpha: 0.05),
            leading: Checkbox(
               value: task.isCompleted,
               onChanged: (val) {
                 final updated = Task(
                    id: task.id, userId: task.userId, listId: task.listId, 
                    title: task.title, description: task.description, 
                    dueDate: task.dueDate, priority: task.priority, 
                    tagIds: task.tagIds, isPinned: task.isPinned, 
                    isCompleted: val ?? false
                 );
                 ref.read(tasksProvider.notifier).updateTask(updated);
               },
               activeColor: GlassTheme.accentColor,
               side: const BorderSide(color: Colors.white54),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                color: Colors.white,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            trailing: Icon(Icons.flag, size: 16, color: _getPriorityColor(task.priority)),
          ),
        );
      },
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 3: return Colors.redAccent;
      case 2: return Colors.orangeAccent;
      case 1: return Colors.blueAccent;
      default: return Colors.grey;
    }
  }
}
