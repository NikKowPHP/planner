import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/task.dart';
import '../models/task_list.dart';

class TodoService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  // Get all lists for current user
  Future<List<TaskList>> getLists() async {
    try {
      final response = await _supabase
          .from('lists')
          .select()
          .order('created_at');
      
      return (response as List).map((e) => TaskList.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Create a new list
  Future<TaskList> createList(String name, {String? color, String? icon}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final response = await _supabase
          .from('lists')
          .insert({
            'user_id': user.id,
            'name': name,
            'color': color,
            'icon': icon,
          })
          .select()
          .single();

      return TaskList.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a list
  Future<void> deleteList(String listId) async {
    try {
      await _supabase.from('lists').delete().eq('id', listId);
    } catch (e) {
      rethrow;
    }
  }

  // Get tasks (optional filter by listId)
  Future<List<Task>> getTasks({String? listId}) async {
    try {
      var query = _supabase.from('tasks').select();
      
      if (listId != null) {
        query = query.eq('list_id', listId);
      }
      
      // Order by is_completed (false first), then priority (desc), then created_at
      final response = await query
          .order('is_completed', ascending: true)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);

      return (response as List).map((e) => Task.fromJson(e)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Create a task
  Future<Task> createTask({
    required String title,
    String? listId,
    String? description,
    DateTime? dueDate,
    int priority = 0,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final response = await _supabase
          .from('tasks')
          .insert({
            'user_id': user.id,
            'list_id': listId,
            'title': title,
            'description': description,
            'due_date': dueDate?.toIso8601String(),
            'priority': priority,
          })
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Update a task
  Future<Task> updateTask(Task task) async {
    try {
      final response = await _supabase
          .from('tasks')
          .update({
            'title': task.title,
            'description': task.description,
            'is_completed': task.isCompleted,
            'priority': task.priority,
            'due_date': task.dueDate?.toIso8601String(),
            'list_id': task.listId,
          })
          .eq('id', task.id)
          .select()
          .single();

      return Task.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  // Toggle task completion
  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) async {
    try {
      await _supabase
          .from('tasks')
          .update({'is_completed': isCompleted})
          .eq('id', taskId);
    } catch (e) {
      rethrow;
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      await _supabase.from('tasks').delete().eq('id', taskId);
    } catch (e) {
      rethrow;
    }
  }
}
