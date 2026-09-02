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

  try {
    final row = await SupabaseClientProvider.client
        .from('profiles')
        .select('id')
        .eq('id', session.user.id)
        .maybeSingle();

    return row == null;
  } catch (_) {
    // Can fire during OAuth redirect before the client is fully ready.
    // Return false (go to home) — the stream will re-trigger once stable.
    return false;
  }
});

/// Shared auth operations.
class AuthService {
  AuthService._();

  /// Create a new account with email + password.
  static Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await SupabaseClientProvider.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign in with existing email + password.
  static Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await SupabaseClientProvider.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await SupabaseClientProvider.client.auth.signOut();
  }
}
