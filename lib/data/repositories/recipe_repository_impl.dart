// Implements the domain contract,
// bridging the data source and the AI recommendation engine.

import '../../domain/entities/recipe_entity.dart';
import '../../domain/entities/recipe_draft.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../datasources/recipe_remote_datasource.dart';
import '../models/recipe_model.dart';

class RecipeRepositoryImpl implements RecipeRepository {
  final RecipeRemoteDataSource remoteDataSource;

  RecipeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<RecipeEntity>> fetchRecipes() async =>
      (await remoteDataSource.getRecipes()).cast<RecipeEntity>();

  @override
  Stream<List<RecipeEntity>> watchRecipes() => remoteDataSource
      .getRecipeFeedStream()
      .map((rows) => rows.map((row) => RecipeModel.fromMap(row)).cast<RecipeEntity>().toList());

  @override
  Future<Map<String, double>> getInteractionWeights(String userId) =>
      remoteDataSource.getInteractionWeights(userId);

  @override
  Future<void> publishRecipe(RecipeDraft draft) => remoteDataSource.publishRecipe(
        title: draft.title,
        ingredients: draft.ingredients,
        instructions: draft.instructions,
        cookingNotes: draft.cookingNotes,
        prepTimeValue: draft.prepTimeValue,
        prepTimeUnit: draft.prepTimeUnit,
        servings: draft.servings,
        region: draft.region,
        difficulty: draft.difficulty,
        tags: draft.tags,
        imageBytesList: draft.photoBytes,
        imageNames: draft.photoNames,
        clientRequestId: draft.clientRequestId,
      );
}
