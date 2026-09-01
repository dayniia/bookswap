import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bookswap/core/supabase_client.dart';

/// The current Supabase [Session], or null if signed out.
final authSessionProvider = StreamProvider<Session?>((ref) {
  return SupabaseClientProvider.client.auth.onAuthStateChange
      .map((event) => event.session);
});

/// True when the signed-in user has no row in `profiles` yet (first login).
final needsProfileSetupProvider = FutureProvider<bool>((ref) async {
  final session = await ref.watch(authSessionProvider.future);
  if (session == null) return false;

  final row = await SupabaseClientProvider.client
      .from('profiles')
      .select('id')
      .eq('id', session.user.id)
      .maybeSingle();

  return row == null;
});

/// Shared auth operations.
class AuthService {
  AuthService._();

  static Future<void> signOut() async {
    await SupabaseClientProvider.client.auth.signOut();
  }
}
