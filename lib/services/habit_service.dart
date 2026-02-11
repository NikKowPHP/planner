import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/habit.dart';
import 'logger.dart';

class HabitService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final FileLogger _logger = FileLogger();

  Future<List<Habit>> getHabits() async {
    try {
      final response = await _supabase
          .from('habits')
          .select()
          .isFilter('deleted_at', null)
          .order('created_at');
      return (response as List).map((e) => Habit.fromJson(e)).toList();
    } catch (e, s) {
      await _logger.error('HabitService: Fetch failed', e, s);
      rethrow;
    }
  }

  Future<List<HabitLog>> getLogs(List<String> habitIds) async {
    if (habitIds.isEmpty) return [];
    try {
      // Fetch logs for the last 365 days to calculate streaks/heatmap
      final since = DateTime.now().subtract(const Duration(days: 365)).toIso8601String();
      final response = await _supabase
          .from('habit_logs')
          .select()
          .inFilter('habit_id', habitIds)
          .gte('completed_at', since);
      return (response as List).map((e) => HabitLog.fromJson(e)).toList();
    } catch (e, s) {
      await _logger.error('HabitService: Fetch logs failed', e, s);
      rethrow;
    }
  }

  Future<Habit> createHabit(String name, {String? icon, String? color, String? reminderTime}) async {
    try {
      final user = _supabase.auth.currentUser!;
      final response = await _supabase.from('habits').insert({
        'user_id': user.id,
        'name': name,
        'icon': icon,
        'color': color,
        'reminder_time': reminderTime,
      }).select().single();
      return Habit.fromJson(response);
    } catch (e, s) {
      await _logger.error('HabitService: Create failed', e, s);
      rethrow;
    }
  }

  Future<void> toggleHabitForDate(String habitId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];
    await _logger.log(
      'HABIT_SERVICE: Toggle remote log for $habitId on $dateStr',
    );
    try {
      // Check existence
      final existing = await _supabase
          .from('habit_logs')
          .select()
          .eq('habit_id', habitId)
          .eq('completed_at', dateStr)
          .maybeSingle();

      if (existing != null) {
        await _logger.log(
          'HABIT_SERVICE: Removing existing log ${existing['id']}',
        );
        await _supabase.from('habit_logs').delete().eq('id', existing['id']);
      } else {
        await _logger.log('HABIT_SERVICE: Inserting new log');
        await _supabase.from('habit_logs').insert({
          'habit_id': habitId,
          'completed_at': dateStr,
          'value': 1
        });
      }
    } catch (e, s) {
      await _logger.error('HABIT_SERVICE: Toggle transaction failed', e, s);
      rethrow;
    }
  }
  
   Future<void> deleteHabit(String habitId) async {
    try {
      await _supabase.from('habits').update({
        'deleted_at': DateTime.now().toIso8601String()
      }).eq('id', habitId);
    } catch (e, s) {
      await _logger.error('HabitService: Delete failed', e, s);
      rethrow;
    }
  }

  Future<void> setArchiveHabit(String habitId, bool archived) async {
    try {
      await _supabase.from('habits').update({
        'is_archived': archived
      }).eq('id', habitId);
    } catch (e, s) {
      await _logger.error('HabitService: Archive failed', e, s);
      rethrow;
    }
  }

  Future<Habit> updateHabit(
    String habitId, {
    String? name,
    String? icon,
    String? color,
    int? goalValue,
    String? reminderTime,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (icon != null) data['icon'] = icon;
      if (color != null) data['color'] = color;
      if (goalValue != null) data['goal_value'] = goalValue;
      if (reminderTime != null) data['reminder_time'] = reminderTime;

      final response = await _supabase
          .from('habits')
          .update(data)
          .eq('id', habitId)
          .select()
          .single();
      return Habit.fromJson(response);
    } catch (e, s) {
      await _logger.error('HabitService: Update failed', e, s);
      rethrow;
    }
  }
}
