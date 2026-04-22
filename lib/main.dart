import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart'; // 🔥 ADD THIS

import '../core/app_export.dart';
import '../widgets/custom_error_widget.dart';
import '../core/utils/storage_helper.dart';
import '../presentation/home_screen/home_screen.dart';
import '../presentation/onboarding_screen/onboarding_screen.dart';

import '../theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 FIREBASE INITIALIZE (MOST IMPORTANT)
  await Firebase.initializeApp();

  final String? token = await StorageHelper.getToken();
  
  bool hasShownError = false;

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;
      Future.delayed(Duration(seconds: 5), () {
        hasShownError = false;
      });
      return CustomErrorWidget(errorDetails: details);
    }
    return SizedBox.shrink();
  };

  // 🚨 CRITICAL: Device orientation lock - DO NOT REMOVE
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // ✅ FIXED SYSTEM UI (LIGHT MODE)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  runApp(MyApp(
    initialRoute: token != null ? AppRoutes.homeScreen : AppRoutes.initial,
  ));
}

class MyApp extends StatefulWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          title: 'libsoar',
          theme: AppTheme.lightTheme,
          // Removed darkTheme and themeMode to default to Light
          themeMode: ThemeMode.light,

          // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.0),
              ),
              child: child!,
            );
          },

          debugShowCheckedModeBanner: false,
          routes: AppRoutes.routes,
          home: widget.initialRoute == AppRoutes.homeScreen 
              ? const HomeScreen() 
              : const OnboardingScreen(),
        );
      },
    );
  }
}