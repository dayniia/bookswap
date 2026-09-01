import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bookswap/core/env.dart';
import 'package:bookswap/core/supabase_client.dart';

/// Handles Google Sign-In on both Android and Web.
///
/// - **Android**: Uses the `google_sign_in` package to show the native
///   account picker, then exchanges the ID token with Supabase via
///   `signInWithIdToken`.
/// - **Web**: Delegates entirely to Supabase's `signInWithOAuth` redirect
///   flow — no `google_sign_in` package involved on web.
class GoogleAuthService {
  GoogleAuthService._();

  static final _googleSignIn = GoogleSignIn(
    // The Web (server) client ID — required on Android so that
    // Google returns an ID token that Supabase can verify.
    serverClientId: Env.googleWebClientId,
  );

  static Future<void> signIn() async {
    if (kIsWeb) {
      await _signInWeb();
    } else {
      await _signInAndroid();
    }
  }

  /// Web: redirect to Google via Supabase OAuth.
  /// Supabase handles the callback and restores the session automatically.
  static Future<void> _signInWeb() async {
    await SupabaseClientProvider.client.auth.signInWithOAuth(
      OAuthProvider.google,
      // null → Supabase uses the current page URL as the redirect target.
      // Make sure http://localhost:* is in Supabase → Auth → URL Configuration → Redirect URLs.
      redirectTo: null,
    );
  }

  /// Android: native account picker → exchange ID token with Supabase.
  static Future<void> _signInAndroid() async {
    // Sign out of any previous Google session so the picker always appears.
    await _googleSignIn.signOut();

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // User cancelled

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) {
      throw Exception(
        'Google Sign-In returned no ID token. '
        'Check that the Web Client ID is correct and the SHA-1 is registered.',
      );
    }

    await SupabaseClientProvider.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
