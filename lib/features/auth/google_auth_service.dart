/// Platform-aware Google auth service.
///
/// On **web** → Supabase OAuth redirect (no google_sign_in package).
/// On **Android/desktop** → native google_sign_in account picker.
///
/// The conditional export ensures only the correct file is compiled
/// for each target, avoiding constructor-not-found errors on web.
export 'google_auth_service_native.dart'
    if (dart.library.html) 'google_auth_service_web.dart';
