import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseConfig {
  static String url = const String.fromEnvironment('SUPABASE_URL');
  static String publishableKey =
      const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// E-posta doğrulama sonrası yönlendirme (localhost değil).
  static String get authRedirectUrl => url;

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  /// `flutter run` için: dart-define yoksa `assets/config/app.env` okunur.
  static Future<void> resolve() async {
    if (isConfigured) return;
    if (_isWidgetTest) return;

    try {
      final raw = await rootBundle.loadString('assets/config/app.env');
      final parsed = _parseEnv(raw);
      url = parsed['SUPABASE_URL'] ?? url;
      publishableKey = parsed['SUPABASE_PUBLISHABLE_KEY'] ?? publishableKey;
    } catch (_) {
      // Asset yoksa yapılandırılmamış kalır.
    }
  }

  static Map<String, String> _parseEnv(String raw) {
    final result = <String, String>{};
    for (final line in raw.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final index = trimmed.indexOf('=');
      if (index <= 0) continue;
      final key = trimmed.substring(0, index).trim();
      final value = trimmed.substring(index + 1).trim();
      result[key] = value;
    }
    return result;
  }

  static bool get _isWidgetTest {
    final name = WidgetsBinding.instance.runtimeType.toString();
    return name.contains('TestWidgetsFlutterBinding');
  }
}

abstract final class SupabaseService {
  static Future<void> initialize() async {
    await SupabaseConfig.resolve();
    if (!SupabaseConfig.isConfigured) return;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    if (kDebugMode) {
      debugPrint('Supabase bağlandı: ${SupabaseConfig.url}');
    }
  }

  static SupabaseClient? get client =>
      SupabaseConfig.isConfigured ? Supabase.instance.client : null;
}
