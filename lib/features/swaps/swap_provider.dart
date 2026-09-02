import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswap/core/supabase_client.dart';
import 'package:bookswap/features/auth/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Status helpers
// ─────────────────────────────────────────────────────────────────────────────

const swapStatusLabels = {
  'pending': 'Pending',
  'accepted': 'Accepted',
  'declined': 'Declined',
  'cancelled': 'Cancelled',
};

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Incoming swap requests to the current user (as listing owner).
final incomingRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null) return [];

  final rows = await SupabaseClientProvider.client
      .from('swap_requests')
      .select(
        'id, status, message, created_at, '
        'listing_id, listings(title, photo_urls), '
        'requester_id, profiles!requester_id(display_name)',
      )
      .eq('owner_id', session.user.id)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(rows);
});

/// Outgoing swap requests made by the current user (as requester).
final outgoingRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null) return [];

  final rows = await SupabaseClientProvider.client
      .from('swap_requests')
      .select(
        'id, status, message, created_at, '
        'listing_id, listings(title, photo_urls), '
        'owner_id, profiles!owner_id(display_name)',
      )
      .eq('requester_id', session.user.id)
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(rows);
});

/// Whether the current user already has a pending request on this listing.
final existingRequestProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, listingId) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null) return null;

  final row = await SupabaseClientProvider.client
      .from('swap_requests')
      .select('id, status')
      .eq('listing_id', listingId)
      .eq('requester_id', session.user.id)
      .maybeSingle();

  return row;
});

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class SwapService {
  SwapService._();

  static Future<void> sendRequest({
    required String listingId,
    required String ownerId,
    String? message,
  }) async {
    final user = SupabaseClientProvider.client.auth.currentUser!;
    await SupabaseClientProvider.client.from('swap_requests').insert({
      'listing_id': listingId,
      'requester_id': user.id,
      'owner_id': ownerId,
      if (message != null && message.isNotEmpty) 'message': message,
    });
  }

  static Future<void> updateStatus(String requestId, String status) async {
    await SupabaseClientProvider.client
        .from('swap_requests')
        .update({'status': status, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', requestId);
  }
}
