import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/cached_recipe_image.dart';
import '../../data/models/recipe_model.dart';
import '../recipe_detail/recipe_detail_screen.dart';
import 'saved_collection_screen.dart';
import 'shared_recipes_tab.dart';

class PublicProfileScreen extends StatelessWidget {
  final String userId;

  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Cook profile')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                FutureBuilder<Map<String, dynamic>?>(
                  future: client.from('users').select('full_name, bio, avatar_url').eq('id', userId).maybeSingle(),
                  builder: (context, snapshot) {
                    final profile = snapshot.data ?? const <String, dynamic>{};
                    final name = (profile['full_name'] ?? 'Home Cook').toString();
                    final avatarUrl = (profile['avatar_url'] ?? '').toString();
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(24)),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: AppColors.backgroundCream,
                            backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl.isEmpty
                                ? Text(name.isEmpty ? 'H' : name[0].toUpperCase(), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.primaryTerracotta))
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          if ((profile['bio'] ?? '').toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(profile['bio'].toString(), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMutedSlate)),
                          ],
                          const SizedBox(height: 12),
                          const Chip(avatar: Icon(Icons.restaurant_menu, size: 17), label: Text('Community cook')),
                        ],
                      ),
                    );
                  },
                ),
                const TabBar(
                  labelColor: AppColors.primaryTerracotta,
                  tabs: [
                    Tab(text: 'Recipes'),
                    Tab(text: 'Shared Posts'),
                    Tab(text: 'Collections'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _PublicRecipesTab(userId: userId),
                      SharedRecipesTab(profileUserId: userId),
                      _PublicCollectionsTab(userId: userId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicRecipesTab extends StatelessWidget {
  final String userId;
  const _PublicRecipesTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: client.from('posts').stream(primaryKey: ['id']).eq('author_id', userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final posts = snapshot.data ?? const [];
        if (posts.isEmpty) return const Center(child: Text('No public recipes yet.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final recipe = RecipeModel.fromMap(posts[index]);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.all(10),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: recipe.imageUrl.isEmpty
                      ? const SizedBox(width: 60, height: 60, child: Icon(Icons.restaurant))
                      : CachedRecipeImage(imageUrl: recipe.imageUrl, width: 60, height: 60),
                ),
                title: Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(recipe.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe))),
              ),
            );
          },
        );
      },
    );
  }
}

class _PublicCollectionsTab extends StatelessWidget {
  final String userId;
  const _PublicCollectionsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: client.from('saved_collections').stream(primaryKey: ['id']).eq('user_id', userId).eq('is_public', true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final collections = snapshot.data ?? const [];
        if (collections.isEmpty) return const Center(child: Text('No public collections yet.'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: collections.length,
          itemBuilder: (context, index) {
            final data = collections[index];
            final ids = List<String>.from(data['saved_post_ids'] ?? const []);
            final name = (data['collection_name'] ?? 'Collection').toString();
            return Card(
              color: AppColors.surfaceWhite,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.folder_special, color: AppColors.primaryTerracotta, size: 32),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${ids.length} recipes saved'),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textMutedSlate),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SavedCollectionScreen(name: name, recipeIds: ids))),
              ),
            );
          },
        );
      },
    );
  }
}
