import 'dart:typed_data';

class RecipeDraft {
  final String title;
  final List<String> ingredients;
  final String instructions;
  final String cookingNotes;
  final int prepTimeValue;
  final String prepTimeUnit;
  final int servings;
  final String region;
  final String difficulty;
  final List<String> tags;
  final List<Uint8List> photoBytes;
  final List<String> photoNames;
  final String clientRequestId;

  const RecipeDraft({
    required this.title,
    required this.ingredients,
    required this.instructions,
    required this.cookingNotes,
    required this.prepTimeValue,
    required this.prepTimeUnit,
    required this.servings,
    required this.region,
    required this.difficulty,
    required this.tags,
    required this.photoBytes,
    required this.photoNames,
    required this.clientRequestId,
  });
}
