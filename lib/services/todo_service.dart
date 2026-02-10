import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../services/logger.dart';

class TodoService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final FileLogger _logger = FileLogger();

  // Get all lists for current user
  Future<List<TaskList>> getLists() async {
    try {
      await _logger.log(
        'Fetching lists for user: ${_supabase.auth.currentUser?.id}',
      );
      final response = await _supabase
          .from('lists')
          .select()
          .order('created_at');
      
      final lists = (response as List)
          .map((e) => TaskList.fromJson(e))
          .toList();
      await _logger.log('Fetched ${lists.length} lists');
      return lists;
    } catch (e, stack) {
      await _logger.error('Error fetching lists', e, stack);
      rethrow;
    }
  }

  // Create a new list
  Future<TaskList> createList(String name, {String? color, String? icon}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _logger.log('Creating list: $name for user: ${user.id}');
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

      final list = TaskList.fromJson(response);
      await _logger.log('Created list: ${list.id}');
      return list;
    } catch (e, stack) {
      await _logger.error('Error creating list: $name', e, stack);
      rethrow;
    }
  }

  // Delete a list
  Future<void> deleteList(String listId) async {
    try {
      await _logger.log('Deleting list: $listId');
      await _supabase.from('lists').delete().eq('id', listId);
      await _logger.log('Deleted list: $listId');
    } catch (e, stack) {
      await _logger.error('Error deleting list: $listId', e, stack);
      rethrow;
    }
  }

  // Get tasks (optional filter by listId)
  Future<List<Task>> getTasks({String? listId}) async {
    try {
      await _logger.log(
        'Fetching tasks for user: ${_supabase.auth.currentUser?.id}, listId: $listId',
      );
      var query = _supabase.from('tasks').select();
      
      if (listId != null) {
        query = query.eq('list_id', listId);
      }
      
      // Order by is_completed (false first), then priority (desc), then created_at
      final response = await query
          .order('is_completed', ascending: true)
          .order('priority', ascending: false)
          .order('created_at', ascending: false);

      final tasks = (response as List).map((e) => Task.fromJson(e)).toList();
      await _logger.log('Fetched ${tasks.length} tasks');
      return tasks;
    } catch (e, stack) {
      await _logger.error('Error fetching tasks', e, stack);
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

      // Check if profile exists, if not create it (fallback for trigger failure)
      try {
        await _supabase.from('profiles').select().eq('id', user.id).single();
      } catch (e) {
        await _logger.log('Profile missing for user: ${user.id}, creating now...');
        await _supabase.from('profiles').insert({
          'id': user.id,
          'username': user.email?.split('@')[0],
        });
        await _logger.log('Profile created manually');
      }

      await _logger.log('Creating task: $title');
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

      final task = Task.fromJson(response);
      await _logger.log('Created task: ${task.id}');
      return task;
    } catch (e, stack) {
      await _logger.error('Error creating task: $title', e, stack);
      rethrow;
    }
  }

  // Update a task
  Future<Task> updateTask(Task task) async {
    try {
      await _logger.log('Updating task: ${task.id}');
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

      final updatedTask = Task.fromJson(response);
      await _logger.log('Updated task: ${task.id}');
      return updatedTask;
    } catch (e, stack) {
      await _logger.error('Error updating task: ${task.id}', e, stack);
      rethrow;
    }
  }

  // Toggle task completion
  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) async {
    try {
      await _logger.log('Toggling task completion: $taskId to $isCompleted');
      await _supabase
          .from('tasks')
          .update({'is_completed': isCompleted})
          .eq('id', taskId);
      await _logger.log('Toggled task: $taskId');
    } catch (e, stack) {
      await _logger.error('Error toggling task: $taskId', e, stack);
      rethrow;
    }
  }

  // Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      await _logger.log('Deleting task: $taskId');
      await _supabase.from('tasks').delete().eq('id', taskId);
      await _logger.log('Deleted task: $taskId');
    } catch (e, stack) {
      await _logger.error('Error deleting task: $taskId', e, stack);
      rethrow;
    }
  }
}
