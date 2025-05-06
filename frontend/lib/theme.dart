// lib/theme.dart
import 'package:flutter/material.dart';

// Movido para o nível superior
enum ButtonVariant {
  primary,
  secondary,
  success,
  danger,
  warning,
  info,
}

class AppTheme {
  // Cores principais
  static const Color primaryColor = Color(0xFF2196F3);      // Azul
  static const Color secondaryColor = Color(0xFF4CAF50);    // Verde
  static const Color accentColor = Color(0xFFFFC107);       // Amarelo
  static const Color errorColor = Color(0xFFF44336);        // Vermelho
  
  // Cores neutras
  static const Color darkGrey = Color(0xFF333333);
  static const Color mediumGrey = Color(0xFF9E9E9E);
  static const Color lightGrey = Color(0xFFE0E0E0);
  static const Color background = Color(0xFFF5F5F5);

  // Temas
  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      background: background,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      background: darkGrey,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      elevation: 0,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );

  // Estilos de texto
  static const TextStyle headingStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: darkGrey,
  );

  static const TextStyle titleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: darkGrey,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    color: darkGrey,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 14,
    color: mediumGrey,
  );

  // Obter cor do botão com base na variante
  static Color getButtonColor(ButtonVariant variant) {
    switch (variant) {
      case ButtonVariant.primary:
        return primaryColor;
      case ButtonVariant.secondary:
        return secondaryColor;
      case ButtonVariant.success:
        return Colors.green;
      case ButtonVariant.danger:
        return Colors.red;
      case ButtonVariant.warning:
        return Colors.orange;
      case ButtonVariant.info:
        return Colors.cyan;
    }
  }

  // Obter cor clara do botão com base na variante
  static Color getButtonLightColor(ButtonVariant variant) {
    switch (variant) {
      case ButtonVariant.primary:
        return primaryColor.withOpacity(0.2);
      case ButtonVariant.secondary:
        return secondaryColor.withOpacity(0.2);
      case ButtonVariant.success:
        return Colors.green.withOpacity(0.2);
      case ButtonVariant.danger:
        return Colors.red.withOpacity(0.2);
      case ButtonVariant.warning:
        return Colors.orange.withOpacity(0.2);
      case ButtonVariant.info:
        return Colors.cyan.withOpacity(0.2);
    }
  }
}