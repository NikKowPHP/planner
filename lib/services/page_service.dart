import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/page_model.dart';
import 'logger.dart';

class PageService {
  final SupabaseClient _supabase = SupabaseConfig.client;
  final FileLogger _logger = FileLogger();

  Future<List<PageModel>> getPages() async {
    try {
      final response = await _supabase
          .from('pages')
          .select()
          .order('updated_at', ascending: false);
      return (response as List).map((e) => PageModel.fromJson(e)).toList();
    } catch (e, s) {
      await _logger.error('PageService: Fetch failed', e, s);
      rethrow;
    }
  }

  Future<PageModel> createPage({String? parentId, String title = 'Untitled'}) async {
    try {
      final user = _supabase.auth.currentUser!;
      final response = await _supabase.from('pages').insert({
        'user_id': user.id,
        'parent_id': parentId,
        'title': title,
        'content': '',
      }).select().single();
      return PageModel.fromJson(response);
    } catch (e, s) {
      await _logger.error('PageService: Create failed', e, s);
      rethrow;
    }
  }

  Future<void> updatePage(String id, Map<String, dynamic> updates) async {
    try {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('pages').update(updates).eq('id', id);
    } catch (e, s) {
      await _logger.error('PageService: Update failed', e, s);
      rethrow;
    }
  }

  Future<void> deletePage(String id) async {
    try {
      await _supabase.from('pages').delete().eq('id', id);
    } catch (e, s) {
      await _logger.error('PageService: Delete failed', e, s);
      rethrow;
    }
  }
}
