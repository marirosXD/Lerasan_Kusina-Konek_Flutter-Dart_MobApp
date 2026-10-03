import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/cached_recipe_image.dart';
import '../../domain/entities/recipe_entity.dart';

class RecipeDetailScreen extends StatelessWidget {
  final RecipeEntity recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  void _showPhotoViewer(BuildContext context, String imageUrl) {
    final size = MediaQuery.sizeOf(context);
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: (size.width * 0.9).clamp(0, 820).toDouble(),
          height: (size.height * 0.78).clamp(0, 620).toDouble(),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: CachedRecipeImage(imageUrl: imageUrl, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrls = recipe.imageUrls.isEmpty ? [recipe.imageUrl] : recipe.imageUrls;
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: Text(recipe.title),
        backgroundColor: AppColors.primaryTerracotta,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600), // Keeps layout compact & centered on Web/Chrome
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Recipe Header Card (Image + Title + Author Info)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textDarkSlate.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (photoUrls.any((url) => url.isNotEmpty))
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                          child: SizedBox(
                            height: 250,
                            child: PageView.builder(
                              itemCount: photoUrls.length,
                              itemBuilder: (context, index) => GestureDetector(
                                onTap: () => _showPhotoViewer(context, photoUrls[index]),
                                child: CachedRecipeImage(
                                  imageUrl: photoUrls[index],
                                  width: double.infinity,
                                  height: 250,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    recipe.title,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDarkSlate,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundCream,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 18, color: AppColors.primaryTerracotta),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${recipe.prepTimeValue} ${recipe.prepTimeUnit}',
                                        style: const TextStyle(
                                          color: AppColors.textDarkSlate,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.person_outline, size: 18, color: AppColors.secondaryPandan),
                                const SizedBox(width: 4),
                                Text(
                                  'Shared by ${recipe.authorName}',
                                  style: const TextStyle(
                                    color: AppColors.secondaryPandan,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _RecipeInfoChip(icon: Icons.people_outline, label: '${recipe.servings} servings'),
                                _RecipeInfoChip(icon: Icons.signal_cellular_alt, label: recipe.difficulty),
                                if (recipe.region.isNotEmpty)
                                  _RecipeInfoChip(icon: Icons.place_outlined, label: recipe.region),
                              ],
                            ),
                            if (recipe.description.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              const Divider(color: AppColors.dividerColor),
                              const SizedBox(height: 8),
                              Text(
                                recipe.description,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: AppColors.textDarkSlate,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Ingredients Container Card
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textDarkSlate.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.shopping_basket_outlined, color: AppColors.primaryTerracotta),
                          SizedBox(width: 10),
                          Text(
                            'Ingredients',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDarkSlate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: AppColors.dividerColor),
                      const SizedBox(height: 8),
                      if (recipe.ingredients.isEmpty)
                        const Text('No ingredients listed.', style: TextStyle(color: AppColors.textMutedSlate))
                      else
                        ...recipe.ingredients.map(
                          (ingredient) => Container(
                            margin: const EdgeInsets.only(bottom: 8.0),
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundCreamLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.dividerColor.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 18, color: AppColors.secondaryPandan),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    ingredient,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textDarkSlate,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Instructions Container Card
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.textDarkSlate.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.menu_book_outlined, color: AppColors.primaryTerracotta),
                          SizedBox(width: 10),
                          Text(
                            'Instructions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDarkSlate,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: AppColors.dividerColor),
                      const SizedBox(height: 8),
                      if (recipe.instructions.isEmpty)
                        const Text('No instructions listed.', style: TextStyle(color: AppColors.textMutedSlate))
                      else
                        ...recipe.instructions.asMap().entries.map(
                          (entry) => Container(
                            margin: const EdgeInsets.only(bottom: 10.0),
                            padding: const EdgeInsets.all(14.0),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundCreamLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.dividerColor.withOpacity(0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppColors.secondaryPandan,
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: const TextStyle(
                                      color: AppColors.surfaceWhite,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: AppColors.textDarkSlate,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

class _RecipeInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RecipeInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 16, color: AppColors.primaryTerracotta),
        label: Text(label),
        backgroundColor: AppColors.backgroundCream,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      );
}
