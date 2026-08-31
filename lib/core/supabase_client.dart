import 'package:supabase_flutter/supabase_flutter.dart';

/// Convenience accessor for the Supabase client throughout the app.
///
/// Call [SupabaseClientProvider.initialize] once in [main] before using this.
class SupabaseClientProvider {
  SupabaseClientProvider._();

  /// Initialise Supabase. Must be called before [client] is accessed.
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }

  /// The global [SupabaseClient] instance.
  static SupabaseClient get client => Supabase.instance.client;
}
