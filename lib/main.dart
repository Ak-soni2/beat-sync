import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beat_sync/splash_screen.dart'; // We will create this file

// Your Supabase details remain the same
const supabaseUrl = 'https://hoqyxvlgjbzvetbjzsae.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhvcXl4dmxnamJ6dmV0Ymp6c2FlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAwNTIyNTUsImV4cCI6MjA3NTYyODI1NX0.K5VvcAWLxAHB3AGhGlsnX24xIEVqiXfKGgpe6MtHdYc';

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
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const SplashScreen(), // Start with the splash screen
    );
  }
}
