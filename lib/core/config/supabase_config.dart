import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// E-posta doğrulama sonrası yönlendirme (localhost değil).
  static String get authRedirectUrl => url;

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

abstract final class SupabaseService {
  static Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  static SupabaseClient? get client =>
      SupabaseConfig.isConfigured ? Supabase.instance.client : null;
}
