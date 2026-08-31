import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bookswap/core/env.dart';
import 'package:bookswap/core/supabase_client.dart';
import 'package:bookswap/core/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseClientProvider.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: BookSwapApp(),
    ),
  );
}

class BookSwapApp extends ConsumerWidget {
  const BookSwapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BookSwap Ethiopia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A6B3C), // Ethiopian green
          brightness: Brightness.light,
        ),
        fontFamily: 'NotoSansEthiopic',
      ),
      routerConfig: router,
    );
  }
}
