import 'page_model.dart';

class ContentMatch {
  final PageModel page;
  final String snippet; // The text context around the match (e.g. "...hello world...")

  ContentMatch({required this.page, required this.snippet});
}
