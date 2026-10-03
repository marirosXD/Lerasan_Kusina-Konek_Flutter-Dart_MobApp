import '../../domain/entities/recipe_entity.dart';

class RecipeModel extends RecipeEntity {
  const RecipeModel({
    required super.id,
    required super.title,
    required super.description,
    required super.authorId,
    required super.authorName,
    super.authorAvatarUrl,
    required super.imageUrl,
    required super.imageUrls,
    required super.prepTimeMinutes,
    required super.prepTimeValue,
    required super.prepTimeUnit,
    required super.servings,
    required super.region,
    required super.difficulty,
    required super.ingredients,
    required super.instructions,
    required super.tags,
    required super.likesCount,
    super.createdAt,
  });

  factory RecipeModel.fromMap(Map<String, dynamic> map) {
    var authorName = (map['author_name'] ?? map['authorName'] ?? '').toString();
    final users = map['users'];
    if (authorName.isEmpty && users is Map) {
      authorName = (users['full_name'] ?? '').toString();
    }

    final legacyImageUrl = (map['image_url'] ?? map['imageUrl'] ?? '').toString();
    final rawImageUrls = map['image_urls'] ?? map['imageUrls'];
    final imageUrls = rawImageUrls is List
        ? rawImageUrls.map((value) => value.toString()).where((value) => value.isNotEmpty).toList()
        : <String>[];
    if (imageUrls.isEmpty && legacyImageUrl.isNotEmpty) imageUrls.add(legacyImageUrl);

    final rawInstructions = map['instructions'];
    final instructions = rawInstructions is List
        ? List<String>.from(rawInstructions)
        : (rawInstructions?.toString() ?? '')
            .split('\n')
            .map((step) => step.trim())
            .where((step) => step.isNotEmpty)
            .toList();

    return RecipeModel(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['cooking_notes'] ?? map['description'] ?? '').toString(),
      authorId: (map['author_id'] ?? map['authorId'] ?? '').toString(),
      authorName: authorName.isEmpty ? 'Home Cook' : authorName,
      authorAvatarUrl: (map['avatar_url'] ?? map['author_avatar_url'] ?? '').toString(),
      imageUrl: imageUrls.isEmpty ? legacyImageUrl : imageUrls.first,
      imageUrls: imageUrls,
      prepTimeMinutes: ((map['prep_time_minutes'] ?? map['prepTimeMinutes']) as num?)?.toInt() ?? 0,
      prepTimeValue: ((map['prep_time_value'] ?? map['prep_time_minutes'] ?? map['prepTimeMinutes']) as num?)?.toInt() ?? 0,
      prepTimeUnit: (map['prep_time_unit'] ?? 'min').toString(),
      servings: (map['servings'] as num?)?.toInt() ?? 1,
      region: (map['region'] ?? '').toString(),
      difficulty: (map['difficulty'] ?? 'Easy').toString(),
      ingredients: List<String>.from(map['ingredients'] ?? const []),
      instructions: instructions,
      tags: List<String>.from(map['tags'] ?? const []),
      likesCount: ((map['likes_count'] ?? map['likesCount']) as num?)?.toInt() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : (map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'instructions': instructions.join('\n'),
        'prep_time_minutes': prepTimeMinutes,
        'prep_time_value': prepTimeValue,
        'prep_time_unit': prepTimeUnit,
        'servings': servings,
        'region': region,
        'difficulty': difficulty,
        'image_url': imageUrl,
        'image_urls': imageUrls,
        'ingredients': ingredients,
        'tags': tags,
        'author_id': authorId,
        'likes_count': likesCount,
      };
}
