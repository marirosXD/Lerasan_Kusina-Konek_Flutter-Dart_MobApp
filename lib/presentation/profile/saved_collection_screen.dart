import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/cached_recipe_image.dart';
import '../../data/models/recipe_model.dart';
import '../recipe_detail/recipe_detail_screen.dart';

class SavedCollectionScreen extends StatelessWidget {
  final String name;
  final List<String> recipeIds;

  const SavedCollectionScreen({super.key, required this.name, required this.recipeIds});

  Future<List<RecipeModel>> _loadRecipes() async {
    if (recipeIds.isEmpty) return [];
    final rows = await Supabase.instance.client
        .from('posts')
        .select()
        .inFilter('id', recipeIds);
    final byId = {
      for (final row in rows)
        (row['id'] as Object).toString(): RecipeModel.fromMap(row),
    };
    return recipeIds.map((id) => byId[id]).whereType<RecipeModel>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Text(name),
        backgroundColor: AppColors.primaryTerracotta,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body: FutureBuilder<List<RecipeModel>>(
        future: _loadRecipes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryTerracotta));
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load this collection. Try again later.'));
          }
          final recipes = snapshot.data ?? [];
          if (recipes.isEmpty) {
            return const Center(child: Text('This collection has no saved recipes yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return Card(
                color: AppColors.surfaceWhite,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: recipe.imageUrl.isEmpty
                      ? const Icon(Icons.restaurant, color: AppColors.primaryTerracotta)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedRecipeImage(imageUrl: recipe.imageUrl, width: 52, height: 52),
                        ),
                  title: Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(recipe.authorName),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
