import 'package:flutter/material.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authenticated = await ApiService.instance.restoreSession();
  runApp(NucleiTechApp(authenticated: authenticated));
}

class NucleiTechApp extends StatelessWidget {
  const NucleiTechApp({
    super.key,
    required this.authenticated,
  });

  final bool authenticated;

  static const primaryBlue = Color(0xFF0B5ED7);
  static const darkBlue = Color(0xFF084298);
  static const paleBlue = Color(0xFFF4F8FF);
  static const borderBlue = Color(0xFFD8E6FA);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryBlue,
      onPrimary: Colors.white,
      secondary: darkBlue,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF172033),
      outline: const Color(0xFFB8C8DE),
      outlineVariant: borderBlue,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFAFCFF),
      surfaceContainer: paleBlue,
      surfaceContainerHigh: const Color(0xFFEDF4FE),
      surfaceContainerHighest: const Color(0xFFE4EEFC),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        dividerColor: borderBlue,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Colors.white,
          unselectedLabelColor: Color(0xFFCFE2FF),
          indicatorColor: Colors.white,
          dividerColor: Colors.transparent,
          labelStyle: TextStyle(fontWeight: FontWeight.w800),
          unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: borderBlue),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: paleBlue,
          labelStyle: const TextStyle(color: darkBlue),
          floatingLabelStyle: const TextStyle(
            color: primaryBlue,
            fontWeight: FontWeight.w700,
          ),
          prefixIconColor: primaryBlue,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderBlue),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderBlue),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryBlue, width: 1.8),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFA9C7F2),
            disabledForegroundColor: Colors.white,
            minimumSize: const Size(0, 50),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryBlue,
            minimumSize: const Size(0, 46),
            side: const BorderSide(color: primaryBlue),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primaryBlue,
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          extendedTextStyle: TextStyle(fontWeight: FontWeight.w800),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: primaryBlue,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: darkBlue,
          contentTextStyle: const TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      home: authenticated ? const HomeScreen() : const LoginScreen(),
    );
  }
}
