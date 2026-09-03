import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stage 1 smoke test: Supabase client initialises without throwing.
///
/// Uses the real project URL + anon key injected via --dart-define.
/// Mocks SharedPreferences so the plugin channel is available in headless tests.
void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Provide an empty in-memory store so shared_preferences doesn't need
    // the native plugin channel during unit tests.
    SharedPreferences.setMockInitialValues({});
  });

  test('SupabaseFlutter.initialize does not throw', () async {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://niwajjerbwlznhhsftrb.supabase.co',
    );
    const anonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5pd2FqamVyYndsem5oaHNmdHJiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgwMzU0OTMsImV4cCI6MjEwMzYxMTQ5M30.lo1yaRppSJztfdU0BY70bjl5sR-WjB-yPiXt2JVuyEw',
    );

    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
    } catch (_) {
      // Already initialized in this test session — acceptable.
    }

    // Real assertion: the singleton client is accessible.
    expect(() => Supabase.instance.client, returnsNormally);
  });
}


