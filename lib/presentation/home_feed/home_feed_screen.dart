import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/cached_recipe_image.dart';
import '../../core/widgets/kusina_brand_mark.dart';
import '../auth/login_screen.dart';
import '../recipe_detail/recipe_detail_screen.dart';
import '../profile/public_profile_screen.dart';
import '../../domain/entities/recipe_entity.dart';
import '../main_navigation_screen.dart';
import 'feed_cubit.dart';
import 'widgets/saved_collections_sheet.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  bool _isRefreshingSession = false;

  @override
  void initState() {
    super.initState();
    // Listen for tab changes and refresh when returning to home tab
    navigationTabNotifier.addListener(_onTabChange);
  }

  @override
  void dispose() {
    navigationTabNotifier.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    // When switching to home tab (0), refresh the feed
    if (navigationTabNotifier.value == 0) {
      try {
        context.read<FeedCubit>().refreshRecommendations();
      } catch (e) {
        debugPrint('Could not refresh feed on tab change: $e');
      }
    }
  }

  Future<void> _retryFeed() async {
    setState(() => _isRefreshingSession = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession != null) {
        await auth.refreshSession();
      }
      if (!mounted) return;
      await context.read<FeedCubit>().start(auth.currentUser?.id ?? '');
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh your session: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reconnect: $error')),
      );
    } finally {
      if (mounted) setState(() => _isRefreshingSession = false);
    }
  }

  Future<void> _signInAgain() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.textDarkSlate,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actionsPadding: const EdgeInsets.only(right: 8),
        title: const KusinaBrandMark(),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search recipes',
            onPressed: () async {
              final recipe = await showSearch<RecipeEntity?>(
                context: context,
                delegate: _RecipeSearchDelegate(context.read<FeedCubit>().state.recipes),
              );
              if (recipe == null || !context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: BlocBuilder<FeedCubit, FeedState>(
            builder: (context, state) {
              if (state.isLoading && state.recipes.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryTerracotta));
              }

              if (state.error != null && state.recipes.isEmpty) {
                final error = state.error.toString();
                final isJwtError = error.contains('PGRST303') ||
                    error.toLowerCase().contains('jwt issued at future');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off, size: 42, color: AppColors.primaryTerracotta),
                        const SizedBox(height: 12),
                        Text(
                          isJwtError ? 'Your sign-in token is out of sync with the server.' : 'We could not load the recipe feed.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDarkSlate),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isJwtError
                              ? 'Refresh your session or sign in again. If a fresh sign-in still fails, the Supabase project may be issuing tokens ahead of the database API clock.'
                              : 'Check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMutedSlate),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            FilledButton(
                              onPressed: _isRefreshingSession ? null : _retryFeed,
                              child: _isRefreshingSession
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Refresh feed'),
                            ),
                            if (isJwtError)
                              TextButton(onPressed: _signInAgain, child: const Text('Sign in again')),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state.recipes.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _retryFeed,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Center(child: Text('No recipes shared yet.\nBe the first to post!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMutedSlate, fontSize: 16))),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _retryFeed,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: state.recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = state.recipes[index];
                    return _SocialRecipeCard(
                      key: ValueKey(recipe.id),
                      recipe: recipe,
                      docId: recipe.id,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RecipeSearchDelegate extends SearchDelegate<RecipeEntity?> {
  final List<RecipeEntity> recipes;

  _RecipeSearchDelegate(this.recipes);

  List<RecipeEntity> get _matches {
    final search = query.trim().toLowerCase();
    if (search.isEmpty) return recipes;
    return recipes.where((recipe) {
      final searchable = [
        recipe.title,
        recipe.authorName,
        recipe.description,
        recipe.region,
        ...recipe.ingredients,
        ...recipe.tags,
      ].join(' ').toLowerCase();
      return searchable.contains(search);
    }).toList();
  }

  @override
  String get searchFieldLabel => 'Search recipes, ingredients...';

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(icon: const Icon(Icons.clear), tooltip: 'Clear search', onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back',
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildMatches(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildMatches(context);

  Widget _buildMatches(BuildContext context) {
    final matches = _matches;
    if (matches.isEmpty) {
      return const Center(child: Text('No matching recipes found.'));
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final recipe = matches[index];
        return ListTile(
          leading: const Icon(Icons.restaurant_menu, color: AppColors.primaryTerracotta),
          title: Text(recipe.title),
          subtitle: Text('By ${recipe.authorName}'),
          onTap: () => close(context, recipe),
        );
      },
    );
  }
}

class _SocialRecipeCard extends StatefulWidget {
  final RecipeEntity recipe;
  final String docId;

  const _SocialRecipeCard({super.key, required this.recipe, required this.docId});

  @override
  State<_SocialRecipeCard> createState() => _SocialRecipeCardState();
}

class _SocialRecipeCardState extends State<_SocialRecipeCard> {
  bool _isLiked = false;
  bool _isLikeBusy = false;
  late int _likeCount;
  int _commentCount = 0;

  Future<void> _shareRecipe() async {
    final recipe = widget.recipe;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final photo = recipe.imageUrls.isEmpty ? recipe.imageUrl : recipe.imageUrls.first;
    final shareText = StringBuffer()
      ..writeln(recipe.title)
      ..writeln('By ${recipe.authorName}')
      ..writeln()
      ..writeln('Ingredients:')
      ..writeln(recipe.ingredients.map((item) => '• $item').join('\n'))
      ..writeln()
      ..writeln('Instructions:')
      ..writeln(recipe.instructions.asMap().entries.map((entry) => '${entry.key + 1}. ${entry.value}').join('\n'));
    if (recipe.description.isNotEmpty) {
      shareText..writeln()..writeln('Cooking tips: ${recipe.description}');
    }
    if (photo.isNotEmpty) shareText..writeln()..writeln('Recipe photo: $photo');

    Object? historyError;
    if (userId != null) {
      try {
        await Supabase.instance.client.from('post_shares').insert({
          'user_id': userId,
          'post_id': widget.docId,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post shared — added to your profile.')),
          );
        }
      } catch (error) {
        historyError = error;
      }
    }

    try {
      await SharePlus.instance.share(
        ShareParams(title: 'Recipe: ${recipe.title}', text: shareText.toString()),
      );
      if (historyError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing opened, but the recipe could not be added to your Shared profile.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open sharing options: $error')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _likeCount = widget.recipe.likesCount;
    _loadLikeState();
    _loadCommentCount();
  }

  Future<void> _loadLikeState() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final result = await Supabase.instance.client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', user.id)
          .eq('post_id', widget.docId)
          .maybeSingle();
      if (mounted) setState(() => _isLiked = result != null);
    } catch (_) {
      // The feed remains usable if the project has not applied the latest schema yet.
    }
  }

  Future<void> _loadCommentCount() async {
    try {
      final comments = await Supabase.instance.client
          .from('interactions')
          .select('id')
          .eq('post_id', widget.docId)
          .eq('interaction_type', 'comment');
      if (mounted) setState(() => _commentCount = comments.length);
    } catch (_) {
      // Keep the feed usable if comment counts are unavailable.
    }
  }

  String _formatTimestamp(DateTime? time) {
    if (time == null) return 'Just now';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _toggleLike() async {
    if (_isLikeBusy) return;
    setState(() => _isLikeBusy = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Please sign in to like a recipe.');

      final isLiked = !_isLiked;
      if (isLiked) {
        await client.from('post_likes').insert({
          'user_id': user.id,
          'post_id': widget.docId,
        });
        try {
          await client.from('interactions').insert({
            'user_id': user.id,
            'post_id': widget.docId,
            'interaction_type': 'like',
            'tags': widget.recipe.tags,
          });
        } catch (_) {
          // Likes still work if optional recommendation tracking is unavailable.
        }
      } else {
        await client
            .from('post_likes')
            .delete()
            .eq('user_id', user.id)
            .eq('post_id', widget.docId);
      }

      final post = await client
          .from('posts')
          .select('likes_count')
          .eq('id', widget.docId)
          .single();
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
          _likeCount = (post['likes_count'] as num?)?.toInt() ?? _likeCount;
        });
        context.read<FeedCubit>().refreshRecommendations();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update like: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLikeBusy = false);
    }
  }

  void _showSaveSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SavedCollectionsSheet(recipeId: widget.docId),
    );
  }

  void _showPhotoViewer([String? imageUrl]) {
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
                  child: CachedRecipeImage(
                    imageUrl: imageUrl ?? widget.recipe.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Close photo',
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

  Future<void> _showCommentsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(postId: widget.docId, tags: widget.recipe.tags),
    );
    _loadCommentCount();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final currentUser = Supabase.instance.client.auth.currentUser;
    var avatarUrl = recipe.authorAvatarUrl;
    if (avatarUrl.isEmpty && recipe.authorId == currentUser?.id) {
      avatarUrl = currentUser?.userMetadata?['avatar_url']?.toString() ?? '';
    }
    final photoUrls = recipe.imageUrls.isEmpty ? [recipe.imageUrl] : recipe.imageUrls;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDarkSlate.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: recipe.authorId)),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryTerracotta,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            recipe.authorName.isNotEmpty ? recipe.authorName[0].toUpperCase() : 'C',
                            style: const TextStyle(color: AppColors.surfaceWhite, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: recipe.authorId)),
                        ),
                        child: Text(
                          recipe.authorName,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDarkSlate),
                        ),
                      ),
                      Text(
                        _formatTimestamp(recipe.createdAt),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMutedSlate),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)),
                    );
                  },
                  icon: const Icon(Icons.restaurant, size: 14),
                  label: const Text('View Recipe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.backgroundCream,
                    foregroundColor: AppColors.primaryTerracotta,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 2.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDarkSlate),
                ),
                if (recipe.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    recipe.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: AppColors.textDarkSlate, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (photoUrls.any((url) => url.isNotEmpty))
            SizedBox(
              height: 240,
              child: PageView.builder(
                itemCount: photoUrls.length,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () => _showPhotoViewer(photoUrls[index]),
                  onDoubleTap: _toggleLike,
                  child: CachedRecipeImage(
                    imageUrl: photoUrls[index],
                    width: double.infinity,
                    height: 240,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                IconButton(
                  tooltip: _isLiked ? 'Unlike recipe' : 'Like recipe',
                  icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: _isLiked ? AppColors.primaryTerracotta : AppColors.textDarkSlate),
                  onPressed: _isLikeBusy ? null : _toggleLike,
                ),
                Text('$_likeCount', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDarkSlate)),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'View comments',
                  icon: const Icon(Icons.chat_bubble_outline, color: AppColors.textDarkSlate),
                  onPressed: () => _showCommentsSheet(context),
                ),
                Text('$_commentCount', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDarkSlate)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bookmark_border, color: AppColors.textDarkSlate),
                  tooltip: 'Save to collection',
                  onPressed: _showSaveSheet,
                ),
                IconButton.filledTonal(
                  tooltip: 'Share recipe',
                  icon: const Icon(Icons.ios_share_outlined),
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.secondaryPandan,
                    backgroundColor: AppColors.secondaryPandan.withOpacity(0.12),
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: _shareRecipe,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final String postId;
  final List<String> tags;

  const _CommentsSheet({required this.postId, required this.tags});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  String? _replyToCommentId;
  String? _replyToName;
  bool _isSending = false;
  final Map<String, String> _commentAvatarUrls = {};
  final Set<String> _loadingCommentAvatarIds = {};

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to comment.')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await client.from('interactions').insert({
        'user_id': user.id,
        'post_id': widget.postId,
        'interaction_type': 'comment',
        'comment_text': text,
        'user_name': user.userMetadata?['full_name'] ?? user.email?.split('@').first ?? 'Home Cook',
        'tags': widget.tags,
        'parent_comment_id': _replyToCommentId,
      });
      if (!mounted) return;
      context.read<FeedCubit>().refreshRecommendations();
      _commentController.clear();
      setState(() {
        _replyToCommentId = null;
        _replyToName = null;
      });
      _commentFocusNode.unfocus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not post comment: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _startReply(String rootCommentId, String userName) {
    setState(() {
      _replyToCommentId = rootCommentId;
      _replyToName = userName;
    });
    _commentFocusNode.requestFocus();
  }

  Future<void> _loadCommentAvatars(List<Map<String, dynamic>> comments) async {
    final missingIds = comments
        .map((comment) => comment['user_id']?.toString())
        .whereType<String>()
        .where((id) => !_commentAvatarUrls.containsKey(id) && !_loadingCommentAvatarIds.contains(id))
        .toSet()
        .toList();
    if (missingIds.isEmpty) return;

    _loadingCommentAvatarIds.addAll(missingIds);
    try {
      final profiles = await Supabase.instance.client
          .from('users')
          .select('id, avatar_url')
          .inFilter('id', missingIds);
      for (final profile in profiles) {
        _commentAvatarUrls[profile['id'].toString()] = (profile['avatar_url'] ?? '').toString();
      }
      for (final id in missingIds) {
        _commentAvatarUrls.putIfAbsent(id, () => '');
      }
    } catch (_) {
      for (final id in missingIds) {
        _commentAvatarUrls.putIfAbsent(id, () => '');
      }
    } finally {
      _loadingCommentAvatarIds.removeAll(missingIds);
      if (mounted) setState(() {});
    }
  }

  Future<void> _showCommentActions(String commentId, Offset globalPosition) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      overlay.size.width - globalPosition.dx,
      overlay.size.height - globalPosition.dy,
    );

    final shouldDelete = await showMenu<bool>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      elevation: 8,
      items: const [
        PopupMenuItem<bool>(
          value: true,
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, size: 19, color: AppColors.primaryTerracotta),
              SizedBox(width: 9),
              Text('Delete comment', style: TextStyle(color: AppColors.primaryTerracotta, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
    if (shouldDelete != true || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This will also delete any replies to this comment.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.primaryTerracotta)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client
          .from('interactions')
          .delete()
          .eq('id', commentId)
          .eq('user_id', userId)
          .eq('interaction_type', 'comment');
      if (_replyToCommentId == commentId && mounted) {
        setState(() {
          _replyToCommentId = null;
          _replyToName = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete comment: $error')),
      );
    }
  }

  Widget _buildComment(Map<String, dynamic> comment, String rootCommentId, {bool isReply = false}) {
    final commentId = comment['id'].toString();
    final userName = (comment['user_name'] ?? 'Home Cook').toString();
    final initial = userName.isEmpty ? 'H' : userName.substring(0, 1).toUpperCase();
    final text = (comment['comment_text'] ?? '').toString();
    final client = Supabase.instance.client;
    final avatarUrl = _commentAvatarUrls[comment['user_id']?.toString()] ?? '';

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 44 : 0, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: comment['user_id'] == null
                ? null
                : () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: comment['user_id'].toString())),
                    ),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.secondaryPandan,
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty ? Text(initial, style: const TextStyle(color: Colors.white, fontSize: 13)) : null,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onLongPressStart: comment['user_id']?.toString() == client.auth.currentUser?.id
                      ? (details) => _showCommentActions(commentId, details.globalPosition)
                      : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundCream,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textDarkSlate)),
                        const SizedBox(height: 3),
                        Text(text, style: const TextStyle(color: AppColors.textDarkSlate, height: 1.3)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 1),
                  child: Row(
                    children: [
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: client
                            .from('comment_likes')
                            .stream(primaryKey: ['comment_id', 'user_id'])
                            .eq('comment_id', commentId),
                        builder: (context, snapshot) {
                          final likes = snapshot.data ?? const <Map<String, dynamic>>[];
                          final userId = client.auth.currentUser?.id;
                          final isLiked = userId != null && likes.any((like) => like['user_id'] == userId);
                          return TextButton.icon(
                            onPressed: () async {
                              if (userId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please sign in to like a comment.')),
                                );
                                return;
                              }
                              try {
                                if (isLiked) {
                                  await client
                                      .from('comment_likes')
                                      .delete()
                                      .eq('comment_id', commentId)
                                      .eq('user_id', userId);
                                } else {
                                  await client.from('comment_likes').insert({
                                    'comment_id': commentId,
                                    'user_id': userId,
                                  });
                                }
                              } catch (error) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Could not update comment like: $error')),
                                );
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: isLiked ? AppColors.primaryTerracotta : AppColors.textMutedSlate,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            icon: Icon(isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, size: 15),
                            label: Text(likes.isEmpty ? 'Like' : 'Like ${likes.length}'),
                          );
                        },
                      ),
                      TextButton.icon(
                        onPressed: () => _startReply(rootCommentId, userName),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textMutedSlate,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        icon: const Icon(Icons.reply, size: 17),
                        label: const Text('Reply'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    final availableHeight = MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom;
    final height = (availableHeight * 0.46).clamp(180.0, 460.0).toDouble();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.dividerColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDarkSlate)),
          const SizedBox(height: 12),
          SizedBox(
            height: height,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: client
                  .from('interactions')
                  .stream(primaryKey: ['id'])
                  .eq('post_id', widget.postId)
                  .eq('interaction_type', 'comment')
                  .order('created_at'),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Comments could not be loaded. Please try again.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data ?? const <Map<String, dynamic>>[];
                _loadCommentAvatars(comments);
                final commentIds = comments.map((comment) => comment['id']).toSet();
                final roots = comments.where((comment) {
                  final parentId = comment['parent_comment_id'];
                  return parentId == null || !commentIds.contains(parentId);
                }).toList();
                if (roots.isEmpty) {
                  return const Center(
                    child: Text('No comments yet. Start the conversation!', style: TextStyle(color: AppColors.textMutedSlate)),
                  );
                }

                return ListView(
                  children: [
                    for (final root in roots) ...[
                      _buildComment(root, root['id'].toString()),
                      for (final reply in comments.where((comment) => comment['parent_comment_id'] == root['id']))
                        _buildComment(reply, root['id'].toString(), isReply: true),
                    ],
                  ],
                );
              },
            ),
          ),
          if (_replyToCommentId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(child: Text('Replying to ${_replyToName ?? 'comment'}', style: const TextStyle(color: AppColors.textMutedSlate))),
                  IconButton(
                    tooltip: 'Cancel reply',
                    onPressed: () => setState(() {
                      _replyToCommentId = null;
                      _replyToName = null;
                    }),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: _replyToCommentId == null ? 'Add a comment...' : 'Write a reply...',
                      filled: true,
                      fillColor: AppColors.backgroundCream,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendComment(),
                  ),
                ),
                IconButton(
                  tooltip: _replyToCommentId == null ? 'Post comment' : 'Post reply',
                  onPressed: _isSending ? null : _sendComment,
                  icon: _isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send, color: AppColors.primaryTerracotta),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
