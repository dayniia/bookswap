// Web implementation — compiled only when dart.library.html is present.
// Uses Supabase's signInWithOAuth redirect — no google_sign_in package needed.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bookswap/core/supabase_client.dart';

class GoogleAuthService {
  GoogleAuthService._();

  static Future<void> signIn() async {
    // Pass the current page URL so Supabase redirects back to exactly
    // where the app is running (correct localhost port every time).
    // Requires http://localhost:* in Supabase → Auth → URL Configuration → Redirect URLs.
    final redirectTo = Uri.base.toString();

    await SupabaseClientProvider.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  static Future<void> signOut() async {
    await SupabaseClientProvider.client.auth.signOut();
  }
}
