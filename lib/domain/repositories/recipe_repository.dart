import '../entities/recipe_entity.dart';
import '../entities/recipe_draft.dart';

abstract interface class RecipeRepository {
  Future<List<RecipeEntity>> fetchRecipes();

  Stream<List<RecipeEntity>> watchRecipes();

  Future<Map<String, double>> getInteractionWeights(String userId);

  Future<void> publishRecipe(RecipeDraft draft);
}
