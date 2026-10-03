import '../entities/recipe_draft.dart';
import '../repositories/recipe_repository.dart';

class PublishRecipe {
  final RecipeRepository repository;

  const PublishRecipe(this.repository);

  Future<void> execute(RecipeDraft draft) => repository.publishRecipe(draft);
}
