import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/kusina_brand_mark.dart';
import '../../data/datasources/recipe_draft_local_datasource.dart';
import '../../domain/entities/recipe_draft.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../../domain/usecases/publish_recipe.dart';

class PostRecipeScreen extends StatefulWidget {
  const PostRecipeScreen({super.key});

  @override
  State<PostRecipeScreen> createState() => _PostRecipeScreenState();
}

class _PostRecipeScreenState extends State<PostRecipeScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final List<TextEditingController> _ingredientControllers = [TextEditingController()];
  final List<TextEditingController> _instructionControllers = [TextEditingController()];
  final _notesController = TextEditingController();
  final _tagController = TextEditingController();
  final _prepTimeController = TextEditingController(text: '30');
  final _servingsController = TextEditingController(text: '4');
  final _regionController = TextEditingController();
  String _prepTimeUnit = 'min';
  String _difficulty = 'Easy';

  static const _maxPhotos = 6;
  final List<XFile> _selectedXFiles = [];
  final List<Uint8List> _selectedImageBytes = [];
  final List<String> _uploadImageNames = [];
  final List<String> _tags = [];
  bool _isUploading = false;
  bool _isRestoringDraft = false;
  bool _suspendDraftSave = false;
  bool _pendingUpload = false;
  bool _draftSaveErrorShown = false;
  String? _uploadRequestId;
  Timer? _draftSaveTimer;
  Timer? _retryTimer;
  final _draftDataSource = RecipeDraftLocalDataSource();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    for (final controller in [
      _titleController,
      _notesController,
      _tagController,
      _prepTimeController,
      _servingsController,
      _regionController,
      ..._ingredientControllers,
      ..._instructionControllers,
    ]) {
      _watchController(controller);
    }
    _restoreDraft();
  }

  TextEditingController _newEntryController([String text = '']) {
    final controller = TextEditingController(text: text);
    _watchController(controller);
    return controller;
  }

  void _watchController(TextEditingController controller) {
    controller.addListener(_scheduleDraftSave);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingUpload && !_isUploading) {
      _tryPendingUpload();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftSaveTimer?.cancel();
    _retryTimer?.cancel();
    _titleController.dispose();
    for (final controller in _ingredientControllers) {
      controller.dispose();
    }
    for (final controller in _instructionControllers) {
      controller.dispose();
    }
    _notesController.dispose();
    _tagController.dispose();
    _prepTimeController.dispose();
    _servingsController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  String? get _currentUserId => Supabase.instance.client.auth.currentUser?.id;

  Map<String, dynamic> _draftPayload() => {
        'title': _titleController.text,
        'ingredients': _ingredientControllers.map((controller) => controller.text).toList(),
        'instructions': _instructionControllers.map((controller) => controller.text).toList(),
        'cooking_notes': _notesController.text,
        'prep_time': _prepTimeController.text,
        'prep_time_unit': _prepTimeUnit,
        'servings': _servingsController.text,
        'region': _regionController.text,
        'difficulty': _difficulty,
        'tags': _tags,
        'photo_bytes': _selectedImageBytes.map(base64Encode).toList(),
        'photo_names': _uploadImageNames,
        'pending_upload': _pendingUpload,
        'upload_request_id': _uploadRequestId,
      };

  void _scheduleDraftSave() {
    if (_suspendDraftSave || _isRestoringDraft || _currentUserId == null) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 600), () {
      final userId = _currentUserId;
      if (userId == null) return;
      _draftDataSource.save(userId, _draftPayload()).catchError((Object error) {
        if (mounted && !_draftSaveErrorShown) {
          _draftSaveErrorShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This draft could not be saved on this device.')),
          );
        }
      });
    });
  }

  Future<void> _saveDraftNow() async {
    final userId = _currentUserId;
    if (userId == null) return;
    _draftSaveTimer?.cancel();
    await _draftDataSource.save(userId, _draftPayload());
  }

  Future<void> _restoreDraft() async {
    final userId = _currentUserId;
    if (userId == null) return;
    _isRestoringDraft = true;
    try {
      final draft = await _draftDataSource.load(userId);
      if (draft == null || !mounted) return;
      final ingredientValues = List<String>.from(draft['ingredients'] ?? const []);
      final instructionValues = List<String>.from(draft['instructions'] ?? const []);
      final encodedPhotos = List<String>.from(draft['photo_bytes'] ?? const []);
      final photoNames = List<String>.from(draft['photo_names'] ?? const []);
      setState(() {
        _suspendDraftSave = true;
        _titleController.text = draft['title']?.toString() ?? '';
        _notesController.text = draft['cooking_notes']?.toString() ?? '';
        _prepTimeController.text = draft['prep_time']?.toString() ?? '30';
        _prepTimeUnit = draft['prep_time_unit']?.toString() ?? 'min';
        _servingsController.text = draft['servings']?.toString() ?? '4';
        _regionController.text = draft['region']?.toString() ?? '';
        _difficulty = draft['difficulty']?.toString() ?? 'Easy';
        _tags
          ..clear()
          ..addAll(List<String>.from(draft['tags'] ?? const []));
        _replaceEntryControllers(_ingredientControllers, ingredientValues);
        _replaceEntryControllers(_instructionControllers, instructionValues);
        _selectedXFiles.clear();
        _selectedImageBytes
          ..clear()
          ..addAll(encodedPhotos.take(_maxPhotos).map(base64Decode));
        _uploadImageNames
          ..clear()
          ..addAll(photoNames.take(_selectedImageBytes.length));
        while (_uploadImageNames.length < _selectedImageBytes.length) {
          _uploadImageNames.add('recipe-photo.jpg');
        }
        for (var index = 0; index < _selectedImageBytes.length; index++) {
          _selectedXFiles.add(XFile.fromData(
            _selectedImageBytes[index],
            name: _uploadImageNames[index],
            mimeType: 'image/jpeg',
          ));
        }
        _pendingUpload = draft['pending_upload'] == true;
        _uploadRequestId = draft['upload_request_id']?.toString();
        _suspendDraftSave = false;
      });
      if (_pendingUpload) {
        _startPendingRetry();
        _tryPendingUpload();
      } else if (_draftHasContent(draft)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your saved recipe draft has been restored.')),
        );
      }
    } catch (_) {
      // A malformed or unavailable local draft should not prevent recipe posting.
    } finally {
      _isRestoringDraft = false;
    }
  }

  bool _draftHasContent(Map<String, dynamic> draft) =>
      (draft['title']?.toString().isNotEmpty ?? false) ||
      (draft['ingredients'] as List? ?? const []).isNotEmpty ||
      (draft['instructions'] as List? ?? const []).isNotEmpty ||
      (draft['photo_bytes'] as List? ?? const []).isNotEmpty;

  void _replaceEntryControllers(List<TextEditingController> controllers, List<String> values) {
    for (final controller in controllers) {
      controller.removeListener(_scheduleDraftSave);
      controller.dispose();
    }
    controllers
      ..clear()
      ..addAll(values.isEmpty ? [_newEntryController()] : values.map(_newEntryController));
  }

  Future<void> _pickImages() async {
    final remaining = _maxPhotos - _selectedXFiles.length;
    if (remaining <= 0) return;
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(imageQuality: 90);
    if (pickedFiles.isEmpty) return;

    final filesToAdd = pickedFiles.take(remaining).toList();
    final preparedBytes = <Uint8List>[];
    final preparedNames = <String>[];
    for (final file in filesToAdd) {
      final originalBytes = await file.readAsBytes();
      try {
        final compressedBytes = await FlutterImageCompress.compressWithList(
          originalBytes,
          minWidth: 1600,
          minHeight: 1600,
          quality: 82,
          format: CompressFormat.jpeg,
        );
        preparedBytes.add(compressedBytes);
        final extensionIndex = file.name.lastIndexOf('.');
        final baseName = extensionIndex > 0 ? file.name.substring(0, extensionIndex) : file.name;
        preparedNames.add('$baseName.jpg');
      } catch (_) {
        preparedBytes.add(originalBytes);
        preparedNames.add(file.name);
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedXFiles.addAll(filesToAdd);
      _selectedImageBytes.addAll(preparedBytes);
      _uploadImageNames.addAll(preparedNames);
    });
    _scheduleDraftSave();
    if (pickedFiles.length > remaining && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A recipe can have up to 6 photos.')),
      );
    }
  }

  void _reorderPhotos(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final file = _selectedXFiles.removeAt(oldIndex);
      final bytes = _selectedImageBytes.removeAt(oldIndex);
      final name = _uploadImageNames.removeAt(oldIndex);
      _selectedXFiles.insert(newIndex, file);
      _selectedImageBytes.insert(newIndex, bytes);
      _uploadImageNames.insert(newIndex, name);
    });
    _scheduleDraftSave();
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedXFiles.removeAt(index);
      _selectedImageBytes.removeAt(index);
      _uploadImageNames.removeAt(index);
    });
    _scheduleDraftSave();
  }

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
    _scheduleDraftSave();
  }

  Widget _buildEntryList({
    required String heading,
    required String singularLabel,
    required String hint,
    required List<TextEditingController> controllers,
    required bool multiline,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heading, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDarkSlate)),
        const SizedBox(height: 8),
        for (var index = 0; index < controllers.length; index++) ...[
          Row(
            crossAxisAlignment: multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: controllers[index],
                  minLines: multiline ? 2 : 1,
                  maxLines: multiline ? 3 : 1,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppColors.textDarkSlate, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: '$singularLabel ${index + 1}',
                    hintText: hint,
                    filled: true,
                    fillColor: AppColors.surfaceWhite,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter $singularLabel or remove this field'
                      : null,
                ),
              ),
              if (index == controllers.length - 1) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Add ${singularLabel.toLowerCase()}',
                  child: FilledButton.icon(
                    onPressed: () => setState(() => controllers.add(_newEntryController())),
                    icon: const Icon(Icons.add, size: 22),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryTerracotta,
                      foregroundColor: AppColors.surfaceWhite,
                      minimumSize: const Size(76, 56),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Remove $singularLabel ${index + 1}',
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.primaryTerracotta, size: 30),
                  onPressed: () => setState(() {
                    final controller = controllers.removeAt(index);
                    controller.removeListener(_scheduleDraftSave);
                    controller.dispose();
                    _scheduleDraftSave();
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _submitRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    _pendingUpload = true;
    _uploadRequestId ??= '${_currentUserId ?? 'user'}_${DateTime.now().microsecondsSinceEpoch}';
    try {
      await _saveDraftNow();
    } catch (_) {
      // Continue with the upload; the draft is best-effort if local storage is unavailable.
    }
    await _tryPendingUpload(showSuccess: true, showFailure: true);
  }

  void _startPendingRetry() {
    _retryTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      if (_pendingUpload && !_isUploading) _tryPendingUpload();
    });
  }

  Future<void> _tryPendingUpload({bool showSuccess = false, bool showFailure = false}) async {
    if (!_pendingUpload || _isUploading) return;
    setState(() => _isUploading = true);

    try {
      final draft = RecipeDraft(
        title: _titleController.text.trim(),
        ingredients: _ingredientControllers.map((controller) => controller.text.trim()).toList(),
        instructions: _instructionControllers.map((controller) => controller.text.trim()).join('\n'),
        cookingNotes: _notesController.text.trim(),
        prepTimeValue: int.parse(_prepTimeController.text),
        prepTimeUnit: _prepTimeUnit,
        servings: int.parse(_servingsController.text),
        region: _regionController.text.trim(),
        difficulty: _difficulty,
        tags: List<String>.from(_tags),
        photoBytes: List<Uint8List>.from(_selectedImageBytes),
        photoNames: List<String>.from(_uploadImageNames),
        clientRequestId: _uploadRequestId!,
      );
      await PublishRecipe(context.read<RecipeRepository>()).execute(draft);

      final userId = _currentUserId;
      _pendingUpload = false;
      _retryTimer?.cancel();
      _retryTimer = null;
      if (userId != null) {
        try {
          await _draftDataSource.clear(userId);
        } catch (_) {
          // A successful post is more important than clearing the local copy.
        }
      }
      if (mounted) {
        _resetForm();
        if (showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe published successfully!'),
            backgroundColor: AppColors.secondaryPandan,
          ),
        );
        }
      }
    } catch (error) {
      _pendingUpload = true;
      _startPendingRetry();
      try {
        await _saveDraftNow();
      } catch (_) {
        // Retain the in-memory draft and keep retrying while this screen is open.
      }
      if (mounted) {
        if (showFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not post right now. Your draft is saved on this device and will retry when the connection returns. $error'),
              backgroundColor: AppColors.primaryTerracotta,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _draftSaveTimer?.cancel();
    _suspendDraftSave = true;
    for (final controller in [..._ingredientControllers, ..._instructionControllers]) {
      controller.removeListener(_scheduleDraftSave);
      controller.dispose();
    }
    setState(() {
      _titleController.clear();
      _notesController.clear();
      _tagController.clear();
      _prepTimeController.text = '30';
      _servingsController.text = '4';
      _regionController.clear();
      _ingredientControllers
        ..clear()
        ..add(_newEntryController());
      _instructionControllers
        ..clear()
        ..add(_newEntryController());
      _selectedXFiles.clear();
      _selectedImageBytes.clear();
      _uploadImageNames.clear();
      _tags.clear();
      _prepTimeUnit = 'min';
      _difficulty = 'Easy';
      _uploadRequestId = null;
      _pendingUpload = false;
    });
    _suspendDraftSave = false;
  }

  Widget _buildImagePreview() {
    if (_selectedImageBytes.isEmpty) {
      return InkWell(
        onTap: _pickImages,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.dividerColor),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo, size: 48, color: AppColors.primaryTerracotta),
              SizedBox(height: 8),
              Text('Tap to add recipe photos', style: TextStyle(color: AppColors.textMutedSlate)),
              SizedBox(height: 4),
              Text('Choose up to 6 photos', style: TextStyle(color: AppColors.textMutedSlate, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 130,
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: true,
            onReorder: _reorderPhotos,
            itemCount: _selectedImageBytes.length + (_selectedImageBytes.length < _maxPhotos ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _selectedImageBytes.length) {
                return Padding(
                  key: const ValueKey('add-recipe-photos'),
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 118,
                    child: OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Add photos', textAlign: TextAlign.center),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryTerracotta,
                        side: const BorderSide(color: AppColors.primaryTerracotta),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                key: ObjectKey(_selectedXFiles[index]),
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 118,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(_selectedImageBytes[index], fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: IconButton.filledTonal(
                          tooltip: 'Remove photo ${index + 1}',
                          onPressed: () => _removePhoto(index),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Hold and drag a photo to change its order.', style: TextStyle(color: AppColors.textMutedSlate, fontSize: 12)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      appBar: AppBar(
        title: const KusinaBrandMark(),
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.textDarkSlate,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
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
                  const Text('Share your kitchen story', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDarkSlate)),
                  const SizedBox(height: 4),
                  const Text('Add the details that will help someone cook it.', style: TextStyle(color: AppColors.textMutedSlate)),
                  const SizedBox(height: 18),
                  // Image Selector
                  _buildImagePreview(),
                  const SizedBox(height: 20),

                  // Title Field
                  TextFormField(
                    controller: _titleController,
                    style: const TextStyle(color: AppColors.textDarkSlate),
                    decoration: InputDecoration(
                      labelText: 'Recipe Title',
                      filled: true,
                      fillColor: AppColors.surfaceWhite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildEntryList(
                    heading: 'Ingredients',
                    singularLabel: 'Ingredient',
                    hint: 'For example, 2 cups of rice',
                    controllers: _ingredientControllers,
                    multiline: false,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _prepTimeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            labelText: 'Prep / cook time',
                            prefixIcon: const Icon(Icons.timer_outlined, color: AppColors.primaryTerracotta),
                            filled: true,
                            fillColor: AppColors.surfaceWhite,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            final number = int.tryParse(value ?? '');
                            return number == null || number <= 0 ? 'Enter a number' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _prepTimeUnit,
                          decoration: InputDecoration(
                            labelText: 'Unit',
                            filled: true,
                            fillColor: AppColors.surfaceWhite,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'sec', child: Text('Seconds')),
                            DropdownMenuItem(value: 'min', child: Text('Minutes')),
                            DropdownMenuItem(value: 'hr', child: Text('Hours')),
                          ],
                          onChanged: (value) {
                            setState(() => _prepTimeUnit = value ?? 'min');
                            _scheduleDraftSave();
                          },
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
                          decoration: InputDecoration(
                            labelText: 'Servings',
                            prefixIcon: const Icon(Icons.people_outline, color: AppColors.primaryTerracotta),
                            filled: true,
                            fillColor: AppColors.surfaceWhite,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            final number = int.tryParse(value ?? '');
                            return number == null || number <= 0 ? 'Enter servings' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _regionController,
                          decoration: InputDecoration(
                            labelText: 'Region / style',
                            prefixIcon: const Icon(Icons.place_outlined, color: AppColors.primaryTerracotta),
                            filled: true,
                            fillColor: AppColors.surfaceWhite,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _difficulty,
                    decoration: InputDecoration(
                      labelText: 'Difficulty',
                      prefixIcon: const Icon(Icons.signal_cellular_alt, color: AppColors.primaryTerracotta),
                      filled: true,
                      fillColor: AppColors.surfaceWhite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Easy', child: Text('Easy')),
                      DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                      DropdownMenuItem(value: 'Hard', child: Text('Hard')),
                    ],
                    onChanged: (value) {
                      setState(() => _difficulty = value ?? 'Easy');
                      _scheduleDraftSave();
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildEntryList(
                    heading: 'Cooking Steps',
                    singularLabel: 'Step',
                    hint: 'Describe one action to take',
                    controllers: _instructionControllers,
                    multiline: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(color: AppColors.textDarkSlate),
                    decoration: InputDecoration(
                      labelText: 'Cooking Experience & Tips (optional)',
                      filled: true,
                      fillColor: AppColors.surfaceWhite,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tag Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagController,
                          decoration: InputDecoration(
                            hintText: 'Add a tag (e.g., pork, sinigang)',
                            filled: true,
                            fillColor: AppColors.surfaceWhite,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: AppColors.secondaryPandan, size: 36),
                        onPressed: _addTag,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tag Chips
                  Wrap(
                    spacing: 8,
                    children: _tags.map((tag) {
                      return Chip(
                        label: Text('#$tag'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeTag(tag),
                        backgroundColor: AppColors.backgroundCream,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isUploading ? null : _submitRecipe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTerracotta,
                      foregroundColor: AppColors.surfaceWhite,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isUploading
                        ? const CircularProgressIndicator(color: AppColors.surfaceWhite)
                        : const Text('Post Recipe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
