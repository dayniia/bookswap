// Web implementation — compiled only when dart.library.html is present.
// Uses Supabase's signInWithOAuth redirect — no google_sign_in package needed.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bookswap/core/supabase_client.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static Future<void> signIn() async {
    // Redirects the browser to Google, then back to the app via Supabase callback.
    // Make sure http://localhost:* is in Supabase → Auth → URL Configuration → Redirect URLs.
    await SupabaseClientProvider.client.auth.signInWithOAuth(
      OAuthProvider.google,
      // null = use current page URL as redirect target (works for localhost dev)
      redirectTo: null,
    );
  }

  static Future<void> signOut() async {
    await SupabaseClientProvider.client.auth.signOut();
  }
}
