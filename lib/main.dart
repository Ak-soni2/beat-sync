// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beat_sync/src/screens/splash_screen.dart';
import 'package:beat_sync/src/widgets/no_animation_page_transitions.dart';
import 'package:beat_sync/src/theme/app_theme.dart';

const supabaseUrl = 'https://ukqfvxcvwvsbxeuxgalk.supabase.co';
const supabaseAnonKey = 'sb_publishable_g-0hhEA4ly7TFlsryyqNkg_igiBBr2J';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BeatSync',
      debugShowCheckedModeBanner: false,

      // Remove Hero animations
      navigatorObservers: const <NavigatorObserver>[],

      theme: AppTheme.theme.copyWith(
        // Disable all route transition animations
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: NoAnimationPageTransitionsBuilder(),
            TargetPlatform.iOS: NoAnimationPageTransitionsBuilder(),
            TargetPlatform.linux: NoAnimationPageTransitionsBuilder(),
            TargetPlatform.macOS: NoAnimationPageTransitionsBuilder(),
            TargetPlatform.windows: NoAnimationPageTransitionsBuilder(),
            TargetPlatform.fuchsia: NoAnimationPageTransitionsBuilder(),
          },
        ),
        // Disable ink ripple/highlight animations
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      home: const SplashScreen(),
    );
  }
}
