import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://icavhlialwdbicassjml.supabase.co', 
    anonKey: 'sb_publishable_NftHbrGztfKOFnG0EeDhWA_B4utBtF6',             
  );  

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kusina Konek',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.backgroundCream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryTerracotta,
          primary: AppColors.primaryTerracotta,
          secondary: AppColors.secondaryPandan,
          surface: AppColors.surfaceWhite,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surfaceWhite,
          foregroundColor: AppColors.textDarkSlate,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.dividerColor),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceWhite,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primaryTerracotta, width: 1.6),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primaryTerracotta,
            foregroundColor: AppColors.surfaceWhite,
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: AppColors.textDarkSlate),
          bodyMedium: TextStyle(color: AppColors.textDarkSlate),
        ),
        useMaterial3: true,
      ),
      home: _getInitialScreen(),
    );
  }

  Widget _getInitialScreen() {
    final user = Supabase.instance.client.auth.currentUser;
    return user != null ? const MainNavigationScreen() : const LoginScreen();
  }
}
