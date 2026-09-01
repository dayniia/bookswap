// Native (Android/desktop) implementation — compiled only when dart.library.html is absent.
// Uses the google_sign_in package to show the native account picker.
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bookswap/core/env.dart';
import 'package:bookswap/core/supabase_client.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static Future<void> signIn() async {
    final googleSignIn = GoogleSignIn(
      // The Web (server) client ID — required so Google returns an ID token
      // that Supabase can verify server-side.
      serverClientId: Env.googleWebClientId,
    );

    // Always sign out first so the account picker appears every time.
    await googleSignIn.signOut();

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) return; // User cancelled

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception(
        'Google Sign-In returned no ID token.\n'
        'Check that:\n'
        '  • The Web Client ID dart-define is set correctly\n'
        '  • The SHA-1 fingerprint is registered in Google Cloud Console\n'
        '  • Google provider is enabled in Supabase',
      );
    }

    await SupabaseClientProvider.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  static Future<void> signOut() async {
    final googleSignIn = GoogleSignIn(serverClientId: Env.googleWebClientId);
    await googleSignIn.signOut();
    await SupabaseClientProvider.client.auth.signOut();
  }
}
