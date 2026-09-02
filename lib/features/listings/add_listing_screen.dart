import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bookswap/core/supabase_client.dart';
import 'package:bookswap/features/listings/listings_provider.dart';

/// Screen for posting a new book listing.
class AddListingScreen extends ConsumerStatefulWidget {
  const AddListingScreen({super.key});

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _areaNoteCtrl = TextEditingController();

  String _language = 'en';
  String _condition = 'good';
  String? _cityId;

  // Photos picked by the user (max 3)
  final List<XFile> _pickedPhotos = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _descCtrl.dispose();
    _areaNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_pickedPhotos.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 photos allowed')),
      );
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (file != null) setState(() => _pickedPhotos.add(file));
  }

  void _removePhoto(int index) {
    setState(() => _pickedPhotos.removeAt(index));
  }

  Future<List<String>> _uploadPhotos(String userId) async {
    final urls = <String>[];
    for (final file in _pickedPhotos) {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_${urls.length}.$ext';
      await SupabaseClientProvider.client.storage
          .from('listing-photos')
          .uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      final url = SupabaseClientProvider.client.storage
          .from('listing-photos')
          .getPublicUrl(path);
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a city')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = SupabaseClientProvider.client.auth.currentUser!;
      final photoUrls = await _uploadPhotos(user.id);

      await SupabaseClientProvider.client.from('listings').insert({
        'owner_id': user.id,
        'title': _titleCtrl.text.trim(),
        'author': _authorCtrl.text.trim().isEmpty
            ? null
            : _authorCtrl.text.trim(),
        'language': _language,
        'condition': _condition,
        'city_id': _cityId,
        'area_note': _areaNoteCtrl.text.trim().isEmpty
            ? null
            : _areaNoteCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'photo_urls': photoUrls,
        'status': 'available',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Book listed! ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post listing: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cities = ref.watch(citiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('List a book'),
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Photo picker ──────────────────────────────────────────
            Text('Photos (optional, max 3)',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: Row(
                children: [
                  // Add button
                  if (_pickedPhotos.length < 3)
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: colors.outline, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                          color: colors.surfaceContainerHighest,
                        ),
                        child: Icon(Icons.add_photo_alternate_outlined,
                            size: 32, color: colors.onSurfaceVariant),
                      ),
                    ),
                  // Picked photos
                  ...List.generate(_pickedPhotos.length, (i) {
                    return FutureBuilder<Uint8List>(
                      future: _pickedPhotos[i].readAsBytes(),
                      builder: (ctx, snap) {
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: colors.surfaceContainerHighest,
                                image: snap.hasData
                                    ? DecorationImage(
                                        image: MemoryImage(snap.data!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => _removePhoto(i),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Title ─────────────────────────────────────────────────
            TextFormField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('Book title *', Icons.title_rounded),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 14),

            // ── Author ────────────────────────────────────────────────
            TextFormField(
              controller: _authorCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _deco('Author (optional)', Icons.person_outline),
            ),
            const SizedBox(height: 14),

            // ── Language ──────────────────────────────────────────────
            DropdownButtonFormField<String>(
              value: _language,
              decoration: _deco('Language', Icons.translate_rounded),
              items: languageLabels.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _language = v!),
            ),
            const SizedBox(height: 14),

            // ── Condition ─────────────────────────────────────────────
            DropdownButtonFormField<String>(
              value: _condition,
              decoration: _deco('Condition', Icons.star_outline_rounded),
              items: conditionLabels.entries
                  .map((e) => DropdownMenuItem(
                      value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _condition = v!),
            ),
            const SizedBox(height: 14),

            // ── City ──────────────────────────────────────────────────
            cities.when(
              data: (list) => DropdownButtonFormField<String>(
                value: _cityId,
                decoration: _deco('City *', Icons.location_city_rounded),
                items: list
                    .map((c) => DropdownMenuItem(
                        value: c['id'] as String,
                        child: Text(c['name'] as String)))
                    .toList(),
                onChanged: (v) => setState(() => _cityId = v),
                validator: (v) => v == null ? 'Select a city' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Could not load cities'),
            ),
            const SizedBox(height: 14),

            // ── Area note ─────────────────────────────────────────────
            TextFormField(
              controller: _areaNoteCtrl,
              decoration: _deco(
                'Meeting area (optional)',
                Icons.place_outlined,
              ),
            ),
            const SizedBox(height: 14),

            // ── Description ───────────────────────────────────────────
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: _deco(
                'Description (optional)',
                Icons.notes_rounded,
              ),
            ),
            const SizedBox(height: 32),

            // ── Submit ────────────────────────────────────────────────
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Post listing',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
