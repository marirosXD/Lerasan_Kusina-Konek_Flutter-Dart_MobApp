class RecipeEntity {
  final String id;
  final String title;
  final String description;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final String imageUrl;
  final List<String> imageUrls;
  final int prepTimeMinutes;
  final int prepTimeValue;
  final String prepTimeUnit;
  final int servings;
  final String region;
  final String difficulty;
  final List<String> ingredients;
  final List<String> instructions;
  final List<String> tags; // e.g., ["adobo", "pork", "braised", "saucy"]
  final int likesCount;
  final DateTime? createdAt;

  const RecipeEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.authorId,
    required this.authorName,
    this.authorAvatarUrl = '',
    required this.imageUrl,
    this.imageUrls = const [],
    required this.prepTimeMinutes,
    this.prepTimeValue = 0,
    this.prepTimeUnit = 'min',
    this.servings = 1,
    this.region = '',
    this.difficulty = 'Easy',
    required this.ingredients,
    required this.instructions,
    required this.tags,
    required this.likesCount,
    this.createdAt,
  });
}
