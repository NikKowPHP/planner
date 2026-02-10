import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/task.dart';
import '../models/task_list.dart';
import '../models/tag.dart';
import '../models/custom_filter.dart';
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
      var query = _supabase.from('tasks').select('*, task_tags(tag_id)');
      
      if (listId != null) {
        query = query.eq('list_id', listId);
      }
      
      // Note: We fetch ALL tasks (including deleted) so the Trash view works.
      // Filtering happens on the client side in HomePage.
      
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
    bool isPinned = false,
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
            'is_pinned': isPinned,
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
            'deleted_at': task.deletedAt?.toIso8601String(),
            'is_pinned': task.isPinned,
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

  // MODIFY: Change to Soft Delete
  Future<void> deleteTask(String taskId) async {
    try {
      await _logger.log('Soft deleting task: $taskId');
      await _supabase
          .from('tasks')
          .update({'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', taskId);
    } catch (e, stack) {
      await _logger.error('Error deleting task: $taskId', e, stack);
      rethrow;
    }
  }

  // ADD: Restore Task
  Future<void> restoreTask(String taskId) async {
    try {
      await _logger.log('Restoring task: $taskId');
      await _supabase
          .from('tasks')
          .update({'deleted_at': null})
          .eq('id', taskId);
    } catch (e, stack) {
      await _logger.error('Error restoring task: $taskId', e, stack);
      rethrow;
    }
  }

  // ADD: Get Tags
  Future<List<Tag>> getTags() async {
    try {
      await _logger.log('Fetching tags...');
      final response = await _supabase.from('tags').select().order('name');
      return (response as List).map((e) => Tag.fromJson(e)).toList();
    } catch (e, stack) {
      await _logger.error('Error fetching tags', e, stack);
      rethrow;
    }
  }

  // ADD: Create Tag
  Future<Tag> createTag(String name) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final response = await _supabase
          .from('tags')
          .insert({'user_id': user.id, 'name': name})
          .select()
          .single();
      return Tag.fromJson(response);
    } catch (e, stack) {
      await _logger.error('Error creating tag: $name', e, stack);
      rethrow;
    }
  }

  // NEW METHOD: Duplicate Task
  Future<Task> duplicateTask(Task task) async {
    try {
      await _logger.log('Duplicating task: ${task.id}');

      // 1. Create the task copy
      final newTask = await createTask(
        title: task.title,
        description: task.description,
        listId: task.listId,
        dueDate: task.dueDate,
        priority: task.priority,
        isPinned: task.isPinned,
      );

      // 2. Copy tags (if any)
      if (task.tagIds.isNotEmpty) {
        final tagInserts = task.tagIds
            .map((tagId) => {'task_id': newTask.id, 'tag_id': tagId})
            .toList();

        await _supabase.from('task_tags').insert(tagInserts);

        // Return task with tags (manually add since insert return doesn't join)
        return Task(
          id: newTask.id,
          userId: newTask.userId,
          title: newTask.title,
          description: newTask.description,
          dueDate: newTask.dueDate,
          priority: newTask.priority,
          isPinned: newTask.isPinned,
          listId: newTask.listId,
          tagIds: task.tagIds,
        );
      }

      return newTask;
    } catch (e, stack) {
      await _logger.error('Error duplicating task: ${task.id}', e, stack);
      rethrow;
    }
  }

  // --- CUSTOM FILTERS ---

  Future<List<CustomFilter>> getFilters() async {
    try {
      await _logger.log('Fetching filters...');
      final response = await _supabase
          .from('custom_filters')
          .select()
          .order('name');
      return (response as List).map((e) => CustomFilter.fromJson(e)).toList();
    } catch (e, stack) {
      await _logger.error('Error fetching filters', e, stack);
      rethrow;
    }
  }

  Future<CustomFilter> createFilter(CustomFilter filter) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final response = await _supabase
          .from('custom_filters')
          .insert({
            'user_id': user.id,
            'name': filter.name,
            'icon': filter.icon,
            'color': filter.color,
            'criteria': filter.criteria.toJson(),
          })
          .select()
          .single();
      return CustomFilter.fromJson(response);
    } catch (e, stack) {
      await _logger.error('Error creating filter', e, stack);
      rethrow;
    }
  }

  Future<void> deleteFilter(String id) async {
    try {
      await _logger.log('Deleting filter: $id');
      await _supabase.from('custom_filters').delete().eq('id', id);
    } catch (e, stack) {
      await _logger.error('Error deleting filter: $id', e, stack);
      rethrow;
    }
  }

  Future<CustomFilter> updateFilter(CustomFilter filter) async {
    try {
      await _logger.log('Updating filter: ${filter.id}');
      final response = await _supabase
          .from('custom_filters')
          .update({
            'name': filter.name,
            'icon': filter.icon,
            'color': filter.color,
            'criteria': filter.criteria.toJson(),
          })
          .eq('id', filter.id)
          .select()
          .single();
      return CustomFilter.fromJson(response);
    } catch (e, stack) {
      await _logger.error('Error updating filter: ${filter.id}', e, stack);
      rethrow;
    }
  }
}
