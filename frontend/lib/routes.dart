// lib/routes.dart
import 'package:flutter/material.dart';
import 'package:ceriv_app/screens/splash_screen.dart';
import 'package:ceriv_app/screens/login_screen.dart';
import 'package:ceriv_app/screens/register_screen.dart';
import 'package:ceriv_app/screens/forgot_password_screen.dart';
import 'package:ceriv_app/screens/dashboard_screen.dart';
import 'package:ceriv_app/screens/qr_scan_screen.dart';
import 'package:ceriv_app/screens/history_screen.dart';
import 'package:ceriv_app/screens/justification_screen.dart';
import 'package:ceriv_app/screens/profile_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String dashboard = '/dashboard';
  static const String qrScan = '/qr-scan';
  static const String history = '/history';
  static const String justification = '/justification';
  static const String profile = '/profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case qrScan:
        return MaterialPageRoute(builder: (_) => const QrScanScreen());
      case history:
        return MaterialPageRoute(builder: (_) => const HistoryScreen());
      case justification:
        return MaterialPageRoute(builder: (_) => const JustificationScreen());
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('Rota não encontrada: ${settings.name}'),
            ),
          ),
        );
    }
  }
}