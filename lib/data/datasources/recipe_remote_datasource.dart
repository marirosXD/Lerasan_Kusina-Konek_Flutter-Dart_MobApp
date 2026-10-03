// Handles raw communication with Supabase PostgreSQL and Storage
// for fetching candidate feeds, logging tag interactions,
// and publishing new recipes.

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recipe_model.dart';

class RecipeRemoteDataSource {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch candidate recipes for AI recommendation scoring
  Future<List<RecipeModel>> getRecipes() async {
    final response = await _supabase
        .from('posts')
        .select()
        .order('created_at', ascending: false);

    final data = response as List<dynamic>;
    final posts = data.map((json) => Map<String, dynamic>.from(json as Map)).toList();
    final authorIds = posts
        .map((post) => (post['author_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (authorIds.isNotEmpty) {
      try {
        final profiles = await _supabase
            .from('users')
            .select('id, avatar_url')
            .inFilter('id', authorIds);
        final avatarsByAuthor = {
          for (final profile in profiles)
            profile['id'].toString(): (profile['avatar_url'] ?? '').toString(),
        };
        for (final post in posts) {
          post['author_avatar_url'] = avatarsByAuthor[post['author_id']?.toString()] ?? '';
        }
      } catch (_) {
        // Keep the feed available when profile avatar data cannot be read.
      }
    }
    return posts.map(RecipeModel.fromMap).toList();
  }

  Future<Map<String, double>> getInteractionWeights(String userId) async {
    if (userId.isEmpty) return {};
    final rows = await _supabase
        .from('interactions')
        .select('tags, interaction_type')
        .eq('user_id', userId);
    final weights = <String, double>{};
    for (final row in rows) {
      final weight = switch (row['interaction_type']) {
        'comment' => 1.5,
        'save' => 2.0,
        _ => 1.0,
      };
      for (final value in (row['tags'] as List? ?? const [])) {
        final tag = value.toString().trim().toLowerCase().replaceFirst(RegExp(r'^#'), '');
        if (tag.isNotEmpty) weights[tag] = (weights[tag] ?? 0) + weight;
      }
    }
    return weights;
  }

  /// Publish a new recipe with image binary upload
  Future<void> publishRecipe({
    required String title,
    required List<String> ingredients,
    required String instructions,
    required String cookingNotes,
    required int prepTimeValue,
    required String prepTimeUnit,
    required int servings,
    required String region,
    required String difficulty,
    required List<String> tags,
    required List<Uint8List> imageBytesList,
    required List<String> imageNames,
    required String clientRequestId,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    if (imageBytesList.length != imageNames.length) {
      throw ArgumentError('Photo data and filenames do not match.');
    }
    final existingPost = await _supabase
        .from('posts')
        .select('id')
        .eq('author_id', user.id)
        .eq('client_request_id', clientRequestId)
        .maybeSingle();
    if (existingPost != null) return;

    final uploadedPaths = <String>[];
    try {
      final imageUrls = <String>[];
      for (var index = 0; index < imageBytesList.length; index++) {
        final extension = imageNames[index].contains('.')
            ? imageNames[index].split('.').last.toLowerCase()
            : 'jpg';
        final contentType = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          _ => 'image/jpeg',
        };
        final filePath = 'recipes/${DateTime.now().microsecondsSinceEpoch}_${user.id}_$index.$extension';
        await _supabase.storage.from('recipe_images').uploadBinary(
              filePath,
              imageBytesList[index],
              fileOptions: FileOptions(contentType: contentType),
            );
        uploadedPaths.add(filePath);
        imageUrls.add(_supabase.storage.from('recipe_images').getPublicUrl(filePath));
      }

      await _supabase.from('posts').insert({
      'author_id': user.id,
      'client_request_id': clientRequestId,
      'author_name': user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'Home Cook',
      'title': title,
      'ingredients': ingredients,
      'instructions': instructions,
      'cooking_notes': cookingNotes,
      'prep_time_value': prepTimeValue,
      'prep_time_unit': prepTimeUnit,
      'prep_time_minutes': switch (prepTimeUnit) {
        'hr' => prepTimeValue * 60,
        'sec' => (prepTimeValue / 60).ceil(),
        _ => prepTimeValue,
      },
      'servings': servings,
      'region': region,
      'difficulty': difficulty,
      'image_url': imageUrls.isEmpty ? '' : imageUrls.first,
      'image_urls': imageUrls,
      'tags': tags,
      'likes_count': 0,
      });
    } catch (_) {
      try {
        final existingPost = await _supabase
            .from('posts')
            .select('id')
            .eq('author_id', user.id)
            .eq('client_request_id', clientRequestId)
            .maybeSingle();
        if (existingPost != null) return;
      } catch (_) {
        // Keep handling the original upload or database error.
      }
      if (uploadedPaths.isNotEmpty) {
        try {
          await _supabase.storage.from('recipe_images').remove(uploadedPaths);
        } catch (_) {
          // Preserve the original publish error if cleanup is temporarily unavailable.
        }
      }
      rethrow;
    }
  }

  Future<void> replaceRecipeImage({
    required String postId,
    required Uint8List imageBytes,
    required String imageName,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final filePath = 'recipes/${DateTime.now().microsecondsSinceEpoch}_${user.id}.jpg';
    await _supabase.storage.from('recipe_images').uploadBinary(
          filePath,
          imageBytes,
          fileOptions: FileOptions(contentType: 'image/jpeg'),
        );
    final imageUrl = _supabase.storage.from('recipe_images').getPublicUrl(filePath);
    final post = await _supabase
        .from('posts')
        .select('image_urls, image_url')
        .eq('id', postId)
        .single();
    final rawUrls = post['image_urls'];
    final imageUrls = rawUrls is List
        ? rawUrls.map((value) => value.toString()).toList()
        : <String>[];
    if (imageUrls.isEmpty && post['image_url'] != null) {
      imageUrls.add(post['image_url'].toString());
    }
    if (imageUrls.isEmpty) {
      imageUrls.add(imageUrl);
    } else {
      imageUrls[0] = imageUrl;
    }
    await _supabase.from('posts').update({
      'image_url': imageUrls.first,
      'image_urls': imageUrls,
    }).eq('id', postId);
  }

  /// Real-time stream feed for HomeFeedScreen
  Stream<List<Map<String, dynamic>>> getRecipeFeedStream() {
    return _supabase
        .from('posts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  /// Log interaction tags for recommendation tracking
  Future<void> logTagInteraction(
    String userId,
    List<String> tags, {
    String? postId,
    String? interactionType,
  }) async {
    await _supabase.from('interactions').insert({
      'user_id': userId,
      'post_id': postId,
      'interaction_type': interactionType ?? 'like',
      'tags': tags,
    });
  }
}
