import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecipeDraftLocalDataSource {
  String _keyFor(String userId) => 'kusina_recipe_draft_$userId';

  Future<Map<String, dynamic>?> load(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_keyFor(userId));
    if (encoded == null || encoded.isEmpty) return null;
    final decoded = jsonDecode(encoded);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Future<void> save(String userId, Map<String, dynamic> draft) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_keyFor(userId), jsonEncode(draft));
  }

  Future<void> clear(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_keyFor(userId));
  }
}
