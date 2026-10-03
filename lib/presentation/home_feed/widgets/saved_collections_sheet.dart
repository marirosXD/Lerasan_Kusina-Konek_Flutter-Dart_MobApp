// Implements the bottom sheet for 
// saving recipes into custom folders

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../feed_cubit.dart';

class SavedCollectionsSheet extends StatefulWidget {
  final String recipeId;

  const SavedCollectionsSheet({super.key, required this.recipeId});

  @override
  State<SavedCollectionsSheet> createState() => _SavedCollectionsSheetState();
}

class _SavedCollectionsSheetState extends State<SavedCollectionsSheet> {
  final _collectionNameController = TextEditingController();

  Future<void> _recordSave(String userId) async {
    final post = await Supabase.instance.client
        .from('posts')
        .select('tags')
        .eq('id', widget.recipeId)
        .maybeSingle();
    await Supabase.instance.client.from('interactions').insert({
      'user_id': userId,
      'post_id': widget.recipeId,
      'interaction_type': 'save',
      'tags': post?['tags'] ?? <String>[],
    });
  }

  @override
  void dispose() {
    _collectionNameController.dispose();
    super.dispose();
  }

  Future<void> _createAndSaveCollection() async {
    final name = _collectionNameController.text.trim();
    final user = Supabase.instance.client.auth.currentUser;
    if (name.isEmpty || user == null) return;

    await Supabase.instance.client.from('saved_collections').insert({
      'user_id': user.id,
      'collection_name': name,
      'saved_post_ids': [widget.recipeId],
    });
    await _recordSave(user.id);
    context.read<FeedCubit>().refreshRecommendations();

    _collectionNameController.clear();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to $name!'),
          backgroundColor: AppColors.secondaryPandan,
        ),
      );
    }
  }

  Future<void> _toggleSaveToExisting(String collectionId, List<dynamic> currentIds) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final updatedIds = List<String>.from(currentIds);
    final isSaved = updatedIds.contains(widget.recipeId);

    if (isSaved) {
      updatedIds.remove(widget.recipeId);
    } else {
      updatedIds.add(widget.recipeId);
    }

    await Supabase.instance.client
        .from('saved_collections')
        .update({'saved_post_ids': updatedIds})
        .eq('id', collectionId);
    if (!isSaved) {
      await _recordSave(user.id);
      if (mounted) context.read<FeedCubit>().refreshRecommendations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Save to Collection',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textDarkSlate,
            ),
          ),
          const SizedBox(height: 16),

          // User Collections List
          SizedBox(
            height: 200,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('saved_collections')
                  .stream(primaryKey: ['id'])
                  .eq('user_id', user?.id ?? ''),
              builder: (context, snapshot) {
                final docs = snapshot.data ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No custom collections yet.\nCreate one below!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMutedSlate),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i];
                    final recipeIds = List<String>.from(data['saved_post_ids'] ?? []);
                    final isSaved = recipeIds.contains(widget.recipeId);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color: isSaved ? AppColors.primaryTerracotta : AppColors.textMutedSlate,
                      ),
                      title: Text(
                        data['collection_name'] ?? 'Collection',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${recipeIds.length} items'),
                      onTap: () => _toggleSaveToExisting(data['id'], recipeIds),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(),

          // New Collection Input Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _collectionNameController,
                  decoration: InputDecoration(
                    hintText: 'New Collection Name...',
                    filled: true,
                    fillColor: AppColors.backgroundCream,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _createAndSaveCollection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTerracotta,
                  foregroundColor: AppColors.surfaceWhite,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                child: const Text('Create'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
