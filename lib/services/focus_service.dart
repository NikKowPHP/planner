import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/focus_session.dart';
import 'logger.dart';

class FocusService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final FileLogger _logger = FileLogger();

  Future<FocusSession> saveSession({
    required DateTime startTime,
    required int durationSeconds,
    String? taskId,
    String? habitId,
  }) async {
    try {
      final user = _supabase.auth.currentUser!;
      final endTime = startTime.add(Duration(seconds: durationSeconds));

      final response = await _supabase.from('focus_sessions').insert({
        'user_id': user.id,
        'task_id': taskId,
        'habit_id': habitId,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'duration_seconds': durationSeconds,
      }).select().single();

      return FocusSession.fromJson(response);
    } catch (e, s) {
      await _logger.error('FocusService: Save failed', e, s);
      rethrow;
    }
  }

  Future<List<FocusSession>> getHistory() async {
    try {
      // Fetch last 30 days
      final since = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final response = await _supabase
          .from('focus_sessions')
          .select()
          .gte('start_time', since)
          .order('start_time', ascending: false);
      
      return (response as List).map((e) => FocusSession.fromJson(e)).toList();
    } catch (e, s) {
      await _logger.error('FocusService: Fetch failed', e, s);
      rethrow;
    }
  }
}
