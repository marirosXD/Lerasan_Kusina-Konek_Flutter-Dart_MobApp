import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/cached_recipe_image.dart';
import '../../data/models/recipe_model.dart';
import '../recipe_detail/recipe_detail_screen.dart';

class SharedRecipesTab extends StatelessWidget {
  final String? profileUserId;

  const SharedRecipesTab({super.key, this.profileUserId});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final userId = profileUserId ?? client.auth.currentUser?.id ?? '';
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: client.from('post_shares').stream(primaryKey: ['id']).eq('user_id', userId),
      builder: (context, sharesSnapshot) {
        if (sharesSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final ids = (sharesSnapshot.data ?? const <Map<String, dynamic>>[])
            .map((row) => row['post_id'].toString())
            .toSet()
            .toList();
        if (ids.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                profileUserId == null
                    ? 'Recipes you share with others will appear here.'
                    : 'No shared posts yet.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return FutureBuilder<List<dynamic>>(
          future: client.from('posts').select().inFilter('id', ids),
          builder: (context, postsSnapshot) {
            if (postsSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final posts = postsSnapshot.data ?? const <dynamic>[];
            if (posts.isEmpty) {
              return const Center(child: Text('Those recipes are no longer available.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final recipe = RecipeModel.fromMap(posts[index] as Map<String, dynamic>);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: recipe.imageUrl.isEmpty
                          ? const SizedBox(width: 58, height: 58, child: Icon(Icons.restaurant))
                          : CachedRecipeImage(imageUrl: recipe.imageUrl, width: 58, height: 58),
                    ),
                    title: Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Post Shared · By ${recipe.authorName}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.textMutedSlate),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
