import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswap/core/supabase_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Average star rating and count for a given profile.
final profileRatingProvider =
    FutureProvider.family<({double avg, int count}), String>(
        (ref, profileId) async {
  final rows = await SupabaseClientProvider.client
      .from('ratings')
      .select('stars')
      .eq('rated_id', profileId);

  if (rows.isEmpty) return (avg: 0.0, count: 0);
  final sum = rows.fold<int>(0, (s, r) => s + (r['stars'] as int));
  return (avg: sum / rows.length, count: rows.length);
});

/// Whether the current user has already rated for this swap.
final hasRatedProvider =
    FutureProvider.family<bool, String>((ref, swapRequestId) async {
  final user = SupabaseClientProvider.client.auth.currentUser;
  if (user == null) return false;

  final row = await SupabaseClientProvider.client
      .from('ratings')
      .select('id')
      .eq('swap_request_id', swapRequestId)
      .eq('rater_id', user.id)
      .maybeSingle();

  return row != null;
});

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class RatingService {
  RatingService._();

  static Future<void> submitRating({
    required String swapRequestId,
    required String ratedUserId,
    required int stars,
    String? comment,
  }) async {
    final user = SupabaseClientProvider.client.auth.currentUser!;
    await SupabaseClientProvider.client.from('ratings').insert({
      'swap_request_id': swapRequestId,
      'rater_id': user.id,
      'rated_id': ratedUserId,
      'stars': stars,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  static Future<void> markAsSwapped(String swapRequestId) async {
    await SupabaseClientProvider.client
        .from('swap_requests')
        .update({'status': 'swapped', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', swapRequestId);
  }
}
