import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../home/presentation/home_shell.dart';
import 'auth_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // dart-define yoksa HomeShell; listeler gerçek veri olmadan boş kalır.
    if (!SupabaseConfig.isConfigured) return const HomeShell();

    final client = SupabaseService.client!;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? client.auth.currentSession;
        return session == null ? const AuthPage() : const HomeShell();
      },
    );
  }
}
