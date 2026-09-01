/// Environment configuration for BookSwap.
///
/// Values are injected at build time via --dart-define flags:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ... \
///     --dart-define=GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
///
/// Never hardcode secrets here.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Web (server) OAuth client ID from Google Cloud Console.
  /// Used as the `serverClientId` for google_sign_in on Android
  /// and as the client_id for Supabase OAuth on web.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
}
