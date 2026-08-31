import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stage 1 smoke test: Supabase client initialises without throwing.
///
/// Uses the real project URL + anon key injected via --dart-define.
/// This is an integration-style unit test — it verifies the SDK can be
/// initialised; it does NOT make any network calls.
void main() {
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

    expect(
      () async => Supabase.initialize(url: url, anonKey: anonKey),
      returnsNormally,
    );
  });
}
