import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/recipe_entity.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/usecases/get_personalized_feed.dart';

class FeedState {
  final bool isLoading;
  final Object? error;
  final List<RecipeEntity> recipes;

  const FeedState({
    this.isLoading = true,
    this.error,
    this.recipes = const [],
  });
}

class FeedCubit extends Cubit<FeedState> {
  final RecipeRepository _repository;
  final GetPersonalizedFeed _personalizeFeed;
  StreamSubscription<List<RecipeEntity>>? _subscription;
  String _userId = '';
  Map<String, double> _interactionWeights = {};
  List<RecipeEntity> _candidates = [];

  FeedCubit({
    required RecipeRepository repository,
    required GetPersonalizedFeed personalizeFeed,
  })  : _repository = repository,
        _personalizeFeed = personalizeFeed,
        super(const FeedState());

  Future<void> start(String userId) async {
    _userId = userId;
    emit(const FeedState());
    try {
      _interactionWeights = await _repository.getInteractionWeights(userId);
    } catch (_) {
      _interactionWeights = {};
    }

    await _subscription?.cancel();
    _subscription = _repository.watchRecipes().listen(
      (recipes) {
        _candidates = recipes;
        _emitRanked();
      },
      onError: (Object error) {
        emit(FeedState(isLoading: false, error: error, recipes: state.recipes));
      },
    );
  }

  Future<void> refreshRecommendations() async {
    try {
      _interactionWeights = await _repository.getInteractionWeights(_userId);
      _candidates = await _repository.fetchRecipes();
      _emitRanked();
    } catch (error) {
      if (_candidates.isEmpty) {
        emit(FeedState(isLoading: false, error: error));
      }
    }
  }

  void _emitRanked() {
    final ranked = _personalizeFeed.execute(
      userInteractionWeights: _interactionWeights,
      candidateRecipes: _candidates,
    );
    emit(FeedState(isLoading: false, recipes: ranked));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
