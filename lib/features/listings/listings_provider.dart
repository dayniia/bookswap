import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswap/core/supabase_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Filter model
// ─────────────────────────────────────────────────────────────────────────────

class ListingFilter {
  const ListingFilter({this.search, this.cityId, this.language});

  final String? search;
  final String? cityId;
  final String? language;

  ListingFilter copyWith({
    Object? search = _sentinel,
    Object? cityId = _sentinel,
    Object? language = _sentinel,
  }) {
    return ListingFilter(
      search: search == _sentinel ? this.search : search as String?,
      cityId: cityId == _sentinel ? this.cityId : cityId as String?,
      language: language == _sentinel ? this.language : language as String?,
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      other is ListingFilter &&
      other.search == search &&
      other.cityId == cityId &&
      other.language == language;

  @override
  int get hashCode => Object.hash(search, cityId, language);
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Mutable filter state — updated from the browse screen UI.
final listingFilterProvider =
    StateProvider<ListingFilter>((ref) => const ListingFilter());

/// All available listings, re-fetching whenever the filter changes.
final listingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final filter = ref.watch(listingFilterProvider);

  var query = SupabaseClientProvider.client
      .from('listings')
      .select('id, title, author, language, condition, photo_urls, created_at, '
          'city_id, cities(name), owner_id, profiles(display_name)')
      .eq('status', 'available')
      .order('created_at', ascending: false);

  if (filter.cityId != null) {
    query = query.eq('city_id', filter.cityId!);
  }
  if (filter.language != null) {
    query = query.eq('language', filter.language!);
  }
  if (filter.search != null && filter.search!.isNotEmpty) {
    query = query.or(
      'title.ilike.%${filter.search}%,author.ilike.%${filter.search}%',
    );
  }

  final rows = await query;
  return List<Map<String, dynamic>>.from(rows);
});

/// Cities list for dropdowns (cached for the session).
final citiesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final rows = await SupabaseClientProvider.client
      .from('cities')
      .select('id, name')
      .order('name');
  return List<Map<String, dynamic>>.from(rows);
});

/// Single listing by ID.
final listingDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
  final row = await SupabaseClientProvider.client
      .from('listings')
      .select('*, cities(name), profiles(display_name, area_note)')
      .eq('id', id)
      .maybeSingle();
  return row;
});

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const conditionLabels = {
  'new': 'New',
  'like_new': 'Like New',
  'good': 'Good',
  'acceptable': 'Acceptable',
};

const languageLabels = {
  'am': 'Amharic',
  'en': 'English',
  'ti': 'Tigrinya',
  'om': 'Oromifa',
  'other': 'Other',
};
