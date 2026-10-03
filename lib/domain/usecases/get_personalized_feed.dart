import 'dart:math';
import '../entities/recipe_entity.dart';

class GetPersonalizedFeed {
  String _normalizeTag(String tag) => tag.trim().toLowerCase().replaceFirst(RegExp(r'^#'), '');

  List<RecipeEntity> execute({
    required Map<String, double> userInteractionWeights,
    required List<RecipeEntity> candidateRecipes,
  }) {
    if (userInteractionWeights.isEmpty) {
      final feed = List<RecipeEntity>.from(candidateRecipes);
      feed.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return feed;
    }

    final Set<String> vocabulary = {};
    vocabulary.addAll(userInteractionWeights.keys);
    for (var recipe in candidateRecipes) {
      vocabulary.addAll(recipe.tags.map(_normalizeTag).where((tag) => tag.isNotEmpty));
    }

    final vocabList = vocabulary.toList();

    final List<double> userVector = vocabList.map((tag) {
      return userInteractionWeights[_normalizeTag(tag)] ?? 0.0;
    }).toList();

    final List<MapEntry<RecipeEntity, double>> scoredRecipes = candidateRecipes.map((recipe) {
      final List<double> recipeVector = vocabList.map((tag) {
        return recipe.tags.map(_normalizeTag).contains(tag) ? 1.0 : 0.0;
      }).toList();

      final score = _computeCosineSimilarity(userVector, recipeVector);
      return MapEntry(recipe, score);
    }).toList();

    scoredRecipes.sort((a, b) {
      final scoreComparison = b.value.compareTo(a.value);
      if (scoreComparison != 0) return scoreComparison;
      return (b.key.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.key.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
    });

    return scoredRecipes.map((entry) => entry.key).toList();
  }

  double _computeCosineSimilarity(List<double> vectorA, List<double> vectorB) {
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      normA += vectorA[i] * vectorA[i];
      normB += vectorB[i] * vectorB[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
}
