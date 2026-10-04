import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../auth/login_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  Uint8List? _newAvatarBytes;
  bool _saving = false;
  bool _showPassword = false;

  SupabaseClient get _client => Supabase.instance.client;
  User? get _user => _client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    final metadata = _user?.userMetadata ?? const <String, dynamic>{};
    _nameController = TextEditingController(text: metadata['full_name']?.toString() ?? '');
    _bioController = TextEditingController(text: metadata['bio']?.toString() ?? '');
    _emailController = TextEditingController(text: _user?.email ?? '');
    _loadProfileFields();
  }

  Future<void> _loadProfileFields() async {
    final user = _user;
    if (user == null) return;
    try {
      final profile = await _client
          .from('users')
          .select('full_name, bio')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || profile == null) return;
      if (_nameController.text.isEmpty) _nameController.text = profile['full_name']?.toString() ?? '';
      if (_bioController.text.isEmpty) _bioController.text = profile['bio']?.toString() ?? '';
    } catch (_) {
      // Keep auth metadata values usable if the profile query is unavailable.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _chooseAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _newAvatarBytes = bytes);
  }

  Future<String?> _uploadAvatar(User user) async {
    final bytes = _newAvatarBytes;
    if (bytes == null) return user.userMetadata?['avatar_url']?.toString();
    final path = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('profile_images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _client.storage.from('profile_images').getPublicUrl(path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _user;
    if (user == null) return;
    setState(() => _saving = true);

    try {
      final avatarUrl = await _uploadAvatar(user);
      final name = _nameController.text.trim();
      final bio = _bioController.text.trim();
      await _client.auth.updateUser(UserAttributes(data: {
        'full_name': name,
        'bio': bio,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }));
      await _client.from('users').update({
        'full_name': name,
        'bio': bio,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', user.id);
      await _client.from('posts').update({'author_name': name}).eq('author_id', user.id);

      final nextEmail = _emailController.text.trim();
      var emailMessage = '';
      if (nextEmail != user.email) {
        await _client.auth.updateUser(UserAttributes(email: nextEmail));
        emailMessage = ' Check your email to confirm the address change.';
      }
      if (_passwordController.text.isNotEmpty) {
        await _client.auth.updateUser(UserAttributes(password: _passwordController.text));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Account settings saved.$emailMessage')),
      );
      Navigator.pop(context, true);
    } on AuthException catch (error) {
      if (mounted) _showError(error.message);
    } catch (error) {
      if (mounted) _showError('Could not save account settings: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text('Your profile, recipes, collections, and activity will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep account')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryTerracotta),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _removeAccountPhotos(_user!);
      await _client.rpc('delete_my_account');
      await _client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      if (mounted) _showError('Could not delete your account: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await _client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _removeAccountPhotos(User user) async {
    final posts = await _client
        .from('posts')
        .select('image_url, image_urls')
        .eq('author_id', user.id);
    final recipePaths = <String>{};
    for (final post in posts) {
      final urls = post['image_urls'];
      final candidates = <dynamic>[
        if (urls is List) ...urls,
        if (post['image_url'] != null) post['image_url'],
      ];
      for (final candidate in candidates) {
        final uri = Uri.tryParse(candidate.toString());
        if (uri == null) continue;
        final segments = uri.pathSegments;
        final bucketIndex = segments.indexOf('recipe_images');
        if (bucketIndex >= 0 && bucketIndex + 1 < segments.length) {
          recipePaths.add(segments.skip(bucketIndex + 1).join('/'));
        }
      }
    }
    if (recipePaths.isNotEmpty) {
      await _client.storage.from('recipe_images').remove(recipePaths.toList());
    }

    final avatarFiles = await _client.storage.from('profile_images').list(path: user.id);
    if (avatarFiles.isNotEmpty) {
      await _client.storage.from('profile_images').remove(
        avatarFiles.map((file) => '${user.id}/${file.name}').toList(),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryTerracotta),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _user?.userMetadata?['avatar_url']?.toString();
    ImageProvider? avatarImage;
    if (_newAvatarBytes != null) {
      avatarImage = MemoryImage(_newAvatarBytes!);
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarImage = NetworkImage(avatarUrl);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Account settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor: AppColors.surfaceWhite,
                        backgroundImage: avatarImage,
                        child: _newAvatarBytes == null && (avatarUrl == null || avatarUrl.isEmpty)
                            ? const Icon(Icons.person, size: 52, color: AppColors.primaryTerracotta)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          tooltip: 'Change profile photo',
                          onPressed: _chooseAvatar,
                          icon: const Icon(Icons.camera_alt_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bioController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 180,
                  decoration: const InputDecoration(labelText: 'Bio', hintText: 'A little about you and your cooking'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: 'New password (leave blank to keep current)',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                    ),
                  ),
                  validator: (value) => value != null && value.isNotEmpty && value.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('Save changes'),
                ),
                const SizedBox(height: 20),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Log out'),
                  onTap: _saving ? null : _signOut,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_forever_outlined, color: AppColors.primaryTerracotta),
                  title: const Text('Delete account', style: TextStyle(color: AppColors.primaryTerracotta, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Permanently remove your account and its data'),
                  onTap: _saving ? null : _deleteAccount,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
