import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/cached_recipe_image.dart';
import '../../core/widgets/kusina_brand_mark.dart';
import '../../data/datasources/recipe_remote_datasource.dart';
import '../../data/models/recipe_model.dart';
import '../recipe_detail/recipe_detail_screen.dart';
import 'account_settings_screen.dart';
import 'saved_collection_screen.dart';
import 'shared_recipes_tab.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: const Text('Are you sure you want to delete this recipe post? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await Supabase.instance.client.from('posts').delete().eq('id', docId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.primaryTerracotta)),
          ),
        ],
      ),
    );
  }

  void _navigateToEditScreen(BuildContext context, String docId, RecipeModel recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditRecipeScreen(docId: docId, recipe: recipe),
      ),
    );
  }

  Future<void> _renameCollection(String collectionId, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit collection name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Collection name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || newName == null) return;

    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection name cannot be empty.')),
      );
      return;
    }

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client
          .from('saved_collections')
          .update({'collection_name': trimmedName})
          .eq('id', collectionId)
          .eq('user_id', userId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not rename collection: $error')),
      );
    }
  }

  Future<void> _deleteCollection(String collectionId, String collectionName) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete collection?'),
        content: Text('“$collectionName” will be removed. The recipes themselves will not be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryTerracotta),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || shouldDelete != true) return;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client
          .from('saved_collections')
          .delete()
          .eq('id', collectionId)
          .eq('user_id', userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted “$collectionName”.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete collection: $error')),
      );
    }
  }

  Future<void> _toggleCollectionVisibility(String collectionId, bool isPublic) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('saved_collections')
          .update({'is_public': !isPublic})
          .eq('id', collectionId)
          .eq('user_id', userId);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update collection visibility: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? user?.email?.split('@').first ?? 'Home Cook';
    final avatarUrl = user?.userMetadata?['avatar_url']?.toString() ?? '';
    final bio = user?.userMetadata?['bio']?.toString() ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const KusinaBrandMark(),
        actions: [
          IconButton(
            tooltip: 'Account settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const AccountSettingsScreen()),
              );
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550),
          child: Column(
            children: [
              // Profile Header
              Container(
                width: double.infinity,
                color: AppColors.surfaceWhite,
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: AppColors.backgroundCream,
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty
                          ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 28, color: AppColors.primaryTerracotta, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textDarkSlate),
                    ),
                    const SizedBox(height: 2),
                    Text(user?.email ?? '', style: const TextStyle(color: AppColors.textMutedSlate, fontSize: 13)),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(bio, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMutedSlate)),
                    ],
                  ],
                ),
              ),

              // Tab Bar
              Container(
                color: AppColors.surfaceWhite,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryTerracotta,
                  unselectedLabelColor: AppColors.textMutedSlate,
                  indicatorColor: AppColors.primaryTerracotta,
                  tabs: const [
                    Tab(icon: Icon(Icons.restaurant_menu), text: 'My Posts'),
                    Tab(icon: Icon(Icons.ios_share_outlined), text: 'Shared Posts'),
                    Tab(icon: Icon(Icons.bookmark_outline), text: 'Saved Collections'),
                  ],
                ),
              ),

              // Tab Content Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: User's Own Posts
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: Supabase.instance.client
                          .from('posts')
                          .stream(primaryKey: ['id'])
                          .eq('author_id', user?.id ?? ''),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primaryTerracotta));
                        }

                        final docs = snapshot.data ?? [];
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('You haven\'t posted any recipes yet.', style: TextStyle(color: AppColors.textMutedSlate)),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final recipe = RecipeModel.fromMap(docs[index]);
                            final docId = recipe.id;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: AppColors.surfaceWhite,
                              child: ListTile(
                                leading: recipe.imageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedRecipeImage(imageUrl: recipe.imageUrl, width: 50, height: 50),
                                      )
                                    : const Icon(Icons.restaurant, color: AppColors.primaryTerracotta),
                                title: Text(recipe.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(recipe.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: AppColors.secondaryPandan, size: 20),
                                      onPressed: () => _navigateToEditScreen(context, docId, recipe),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.primaryTerracotta, size: 20),
                                      onPressed: () => _showDeleteDialog(context, docId),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => RecipeDetailScreen(recipe: recipe)));
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),

                    const SharedRecipesTab(),

                    // Tab 3: User's Saved Collections
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: Supabase.instance.client
                          .from('saved_collections')
                          .stream(primaryKey: ['id'])
                          .eq('user_id', user?.id ?? ''),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primaryTerracotta));
                        }

                        final collections = snapshot.data ?? [];
                        if (collections.isEmpty) {
                          return const Center(
                            child: Text('No saved collections yet.\nBookmark recipes on your feed to organize them here!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMutedSlate)),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: collections.length,
                          itemBuilder: (context, i) {
                            final data = collections[i];
                            final recipeIds = List<String>.from(data['saved_post_ids'] ?? []);
                            final isPublic = data['is_public'] == true;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: AppColors.surfaceWhite,
                              child: ListTile(
                                leading: const Icon(Icons.folder_special, color: AppColors.primaryTerracotta, size: 32),
                                title: Text(data['collection_name'] ?? 'Collection', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('${recipeIds.length} recipes saved · ${isPublic ? 'Public' : 'Private'}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PopupMenuButton<String>(
                                      tooltip: 'Collection actions',
                                      onSelected: (action) {
                                        final id = data['id'].toString();
                                        final name = (data['collection_name'] ?? 'Collection').toString();
                                        if (action == 'rename') {
                                          _renameCollection(id, name);
                                        } else if (action == 'delete') {
                                          _deleteCollection(id, name);
                                        } else if (action == 'visibility') {
                                          _toggleCollectionVisibility(id, data['is_public'] == true);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        PopupMenuItem(value: 'visibility', child: Text(isPublic ? 'Make private' : 'Make public')),
                                        const PopupMenuItem(value: 'rename', child: Text('Edit name')),
                                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                                      ],
                                    ),
                                    const Icon(Icons.chevron_right, color: AppColors.textMutedSlate),
                                  ],
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SavedCollectionScreen(
                                      name: data['collection_name'] ?? 'Collection',
                                      recipeIds: recipeIds,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Full-Screen Detailed Editor Component
class EditRecipeScreen extends StatefulWidget {
  final String docId;
  final RecipeModel recipe;

  const EditRecipeScreen({super.key, required this.docId, required this.recipe});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _prepTimeController;
  late TextEditingController _servingsController;
  late TextEditingController _regionController;
  String _prepTimeUnit = 'min';
  String _difficulty = 'Easy';
  XFile? _replacementImage;
  Uint8List? _replacementImageBytes;

  late List<TextEditingController> _ingredientControllers;
  late List<TextEditingController> _instructionControllers;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe.title);
    _descriptionController = TextEditingController(text: widget.recipe.description);
    _prepTimeController = TextEditingController(text: widget.recipe.prepTimeValue.toString());
    _servingsController = TextEditingController(text: widget.recipe.servings.toString());
    _regionController = TextEditingController(text: widget.recipe.region);
    _prepTimeUnit = widget.recipe.prepTimeUnit;
    _difficulty = widget.recipe.difficulty;

    _ingredientControllers = widget.recipe.ingredients.isNotEmpty
        ? widget.recipe.ingredients.map((i) => TextEditingController(text: i)).toList()
        : [TextEditingController()];

    _instructionControllers = widget.recipe.instructions.isNotEmpty
        ? widget.recipe.instructions.map((i) => TextEditingController(text: i)).toList()
        : [TextEditingController()];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _prepTimeController.dispose();
    _servingsController.dispose();
    _regionController.dispose();
    for (var c in _ingredientControllers) {
      c.dispose();
    }
    for (var c in _instructionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addIngredientField() {
    setState(() {
      _ingredientControllers.add(TextEditingController());
    });
  }

  void _addInstructionField() {
    setState(() {
      _instructionControllers.add(TextEditingController());
    });
  }

  Future<void> _pickReplacementImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _replacementImage = file;
      _replacementImageBytes = bytes;
    });
  }

  InputDecoration _customInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: AppColors.surfaceWhite,
      labelStyle: const TextStyle(color: AppColors.textMutedSlate),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryTerracotta, width: 2),
      ),
    );
  }

  Future<void> _updateRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final ingredients = _ingredientControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final instructions = _instructionControllers
          .map((c) => c.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final prepTimeValue = int.tryParse(_prepTimeController.text.trim()) ?? 0;
      final prepTimeMinutes = switch (_prepTimeUnit) {
        'hr' => prepTimeValue * 60,
        'sec' => (prepTimeValue / 60).ceil(),
        _ => prepTimeValue,
      };

      if (_replacementImage != null && _replacementImageBytes != null) {
        await RecipeRemoteDataSource().replaceRecipeImage(
          postId: widget.docId,
          imageBytes: _replacementImageBytes!,
          imageName: _replacementImage!.name,
        );
      }

      await Supabase.instance.client.from('posts').update({
        'title': _titleController.text.trim(),
        'instructions': instructions.join('\n'),
        'cooking_notes': _descriptionController.text.trim(),
        'prep_time_value': prepTimeValue,
        'prep_time_unit': _prepTimeUnit,
        'prep_time_minutes': prepTimeMinutes,
        'servings': int.tryParse(_servingsController.text.trim()) ?? 1,
        'region': _regionController.text.trim(),
        'difficulty': _difficulty,
        'ingredients': ingredients,
      }).eq('id', widget.docId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe updated successfully!'),
            backgroundColor: AppColors.secondaryPandan,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update recipe: $e'),
            backgroundColor: AppColors.primaryTerracotta,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const Text('Edit Recipe Details'),
        backgroundColor: AppColors.primaryTerracotta,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.textDarkSlate.withOpacity(0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    onTap: _pickReplacementImage,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 210,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundCream,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.dividerColor),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_replacementImageBytes != null)
                            Image.memory(_replacementImageBytes!, fit: BoxFit.cover)
                          else if (widget.recipe.imageUrl.isNotEmpty)
                            CachedRecipeImage(imageUrl: widget.recipe.imageUrl, fit: BoxFit.cover)
                          else
                            const Icon(Icons.add_a_photo, size: 48, color: AppColors.primaryTerracotta),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: FilledButton.tonalIcon(
                              onPressed: _pickReplacementImage,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(_replacementImage == null ? 'Change photo' : 'Choose another'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: AppColors.textDarkSlate),
                    decoration: _customInputDecoration('Recipe Title'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.textDarkSlate),
                    decoration: _customInputDecoration('Description & Cooking Notes'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter a description' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _prepTimeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: const TextStyle(color: AppColors.textDarkSlate),
                          decoration: _customInputDecoration('Prep / cook time'),
                          validator: (value) {
                            final time = int.tryParse(value ?? '');
                            return time == null || time <= 0 ? 'Enter a number above zero' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<String>(
                          value: _prepTimeUnit,
                          decoration: _customInputDecoration('Unit'),
                          items: const [
                            DropdownMenuItem(value: 'sec', child: Text('Seconds')),
                            DropdownMenuItem(value: 'min', child: Text('Minutes')),
                            DropdownMenuItem(value: 'hr', child: Text('Hours')),
                          ],
                          onChanged: (value) => setState(() => _prepTimeUnit = value ?? 'min'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _servingsController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _customInputDecoration('Servings'),
                          validator: (value) {
                            final servings = int.tryParse(value ?? '');
                            return servings == null || servings <= 0 ? 'Enter servings' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _regionController,
                          decoration: _customInputDecoration('Region / style'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _difficulty,
                    decoration: _customInputDecoration('Difficulty'),
                    items: const [
                      DropdownMenuItem(value: 'Easy', child: Text('Easy')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'Hard', child: Text('Hard')),
                    ],
                    onChanged: (value) => setState(() => _difficulty = value ?? 'Easy'),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ingredients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDarkSlate)),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.secondaryPandan),
                        onPressed: _addIngredientField,
                      ),
                    ],
                  ),
                  ..._ingredientControllers.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextFormField(
                        controller: entry.value,
                        decoration: _customInputDecoration('Ingredient ${entry.key + 1}'),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDarkSlate)),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.secondaryPandan),
                        onPressed: _addInstructionField,
                      ),
                    ],
                  ),
                  ..._instructionControllers.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: TextFormField(
                        controller: entry.value,
                        decoration: _customInputDecoration('Step ${entry.key + 1}'),
                      ),
                    );
                  }),
                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _isSaving ? null : _updateRecipe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTerracotta,
                      foregroundColor: AppColors.surfaceWhite,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: AppColors.surfaceWhite)
                        : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
