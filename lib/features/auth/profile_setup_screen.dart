import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswap/core/supabase_client.dart';
import 'package:bookswap/core/router.dart';

/// Screen shown once on first login to collect display name, city, and area note.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _areaController = TextEditingController();

  List<Map<String, dynamic>> _cities = [];
  String? _selectedCityId;
  bool _loadingCities = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final rows = await SupabaseClientProvider.client
          .from('cities')
          .select('id, name')
          .order('name');
      if (mounted) {
        setState(() {
          _cities = List<Map<String, dynamic>>.from(rows);
          _loadingCities = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final user = SupabaseClientProvider.client.auth.currentUser!;
    try {
      // Use upsert so re-running profile setup (or re-signing in with an
      // existing account) never hits a duplicate key constraint.
      await SupabaseClientProvider.client.from('profiles').upsert({
        'id': user.id,
        'display_name': _nameController.text.trim(),
        'city_id': _selectedCityId,
        'area_note': _areaController.text.trim().isEmpty
            ? null
            : _areaController.text.trim(),
        'language_pref': 'en',
      }, onConflict: 'id');

      if (mounted) {
        // Navigate to home after profile created
        ref.read(routerProvider).go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Set up your profile',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This helps other swappers know who they\'re dealing with.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),

                    // Display name
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Display name',
                        hintText: 'e.g. Selam T.',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Please enter a display name';
                        }
                        if (v.trim().length < 2) return 'Name is too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // City dropdown — always reads from cities table, never hardcoded
                    _loadingCities
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedCityId,
                            decoration: InputDecoration(
                              labelText: 'City',
                              prefixIcon:
                                  const Icon(Icons.location_city_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _cities
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c['id'] as String,
                                    child: Text(c['name'] as String),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCityId = v),
                            validator: (v) =>
                                v == null ? 'Please select your city' : null,
                          ),
                    const SizedBox(height: 16),

                    // Area note
                    TextFormField(
                      controller: _areaController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Area / meeting note (optional)',
                        hintText:
                            'e.g. Bole, near Medhanialem church',
                        prefixIcon: const Icon(Icons.place_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Continue'),
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
