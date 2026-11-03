import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

import 'package:ezinvoice/screens/app_scaffold.dart';
import 'package:ezinvoice/screens/setup/first_time_setup_screen.dart';
import 'package:ezinvoice/screens/auth/onboarding_screen.dart';
import 'package:ezinvoice/providers/theme_provider.dart';
import 'package:ezinvoice/providers/company_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Origin Invoice',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,

      // ── Light Theme ──────────────────────────────────────────────────────
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1877F2),
          secondary: Color(0xFF1877F2),
          surface: Color(0xFFF5F5F5),
          onPrimary: Colors.white,
        ),
        primaryColor: const Color(0xFF1877F2),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        cardColor: Colors.white,
        cardTheme: const CardThemeData(color: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFF1877F2),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF2C2C2C)),
          bodyMedium: TextStyle(color: Color(0xFF2C2C2C)),
          bodySmall: TextStyle(color: Color(0xFF2C2C2C)),
          titleLarge: TextStyle(color: Color(0xFF2C2C2C)),
          titleMedium: TextStyle(color: Color(0xFF2C2C2C)),
          titleSmall: TextStyle(color: Color(0xFF2C2C2C)),
          labelLarge: TextStyle(color: Color(0xFF2C2C2C)),
          labelMedium: TextStyle(color: Color(0xFF2C2C2C)),
          labelSmall: TextStyle(color: Color(0xFF2C2C2C)),
        ),
      ),

      // ── Dark Theme ───────────────────────────────────────────────────────
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1877F2),
          secondary: Color(0xFF1877F2),
          onPrimary: Colors.white,
          surface: Color(0xFF1E1E1E),
        ),
        primaryColor: const Color(0xFF1877F2),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        cardColor: const Color(0xFF1E1E1E),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFF1877F2),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Colors.red,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          labelStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF6E6E6E),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2A2A2A),
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF1E1E1E),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}

// ── Splash Screen ─────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    // Wait at least 1 second for splash
    await Future.delayed(const Duration(seconds: 1));

    // Then wait for Firebase auth to be ready
    await FirebaseAuth.instance.authStateChanges().first;

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => const AuthGate(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0064E0),
      body: Stack(
        children: [
          Center(
            child: Image(
              image: const AssetImage(
                'assets/icons/ezinvoice.png',
              ),
              width: 200,
              height: 200,
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Text(
              'Origin Invoice',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                shadows: const [
                  Shadow(
                    color: Color(0x26000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Listens to Firebase auth — shows login or app accordingly
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const OnboardingScreen();
        }

        return const InitialAppLoader();
      },
    );
  }
}

class InitialAppLoader extends ConsumerStatefulWidget {
  const InitialAppLoader({super.key});

  @override
  ConsumerState<InitialAppLoader> createState() =>
      _InitialAppLoaderState();
}

class _InitialAppLoaderState extends ConsumerState<InitialAppLoader> {
  bool _checkingPreviousCompany = true;
  bool _hasPreviouslyUsedCompany = false;

  @override
  void initState() {
    super.initState();
    _checkPreviousCompany();
  }

  Future<void> _checkPreviousCompany() async {
    final prefs = await SharedPreferences.getInstance();

    final hasCompany = prefs.getBool('has_company') ?? false;

    if (mounted) {
      setState(() {
        _hasPreviouslyUsedCompany = hasCompany;
        _checkingPreviousCompany = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyListAsync = ref.watch(companyListProvider);

    // Check local memory first.
    if (_checkingPreviousCompany) {
      return const SplashScreen();
    }

    return companyListAsync.when(
      loading: () => const SplashScreen(),

      error: (error, stack) {
        // If this user has already configured a company,
        // don't send them to setup just because Firebase
        // cannot currently reach the server.
        if (_hasPreviouslyUsedCompany) {
          return const AppScaffold();
        }

        return Scaffold(
          body: Center(
            child: Text(
              'Fatal Error: ${error.toString()}',
            ),
          ),
        );
      },

      data: (companies) {
        // Normal case: companies are available from Firestore
        // or its local cache.
        if (companies.isNotEmpty) {
          return const AppScaffold();
        }

        // IMPORTANT:
        // If the user has previously configured a company,
        // an empty result must NOT immediately mean
        // "First Time Setup".
        //
        // Firestore may still be loading local cached data,
        // especially during offline startup.
        if (_hasPreviouslyUsedCompany) {
          return const SplashScreen();
        }

        // No company has ever been configured.
        return const FirstTimeSetupScreen();
      },
    );
  }
}