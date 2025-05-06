// lib/widgets/custom_button.dart
import 'package:flutter/material.dart';
import 'package:ceriv_app/theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppTheme.ButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final double height;
  final double? width;
  final IconData? icon;
  final bool outlined;
  final EdgeInsets padding;
  final double borderRadius;
  final double fontSize;

  const CustomButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.variant = AppTheme.ButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = false,
    this.height = 48.0,
    this.width,
    this.icon,
    this.outlined = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = 8.0,
    this.fontSize = 16.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonColor = AppTheme.getButtonColor(variant);
    final textColor = outlined ? buttonColor : Colors.white;
    
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: outlined ? Colors.transparent : buttonColor,
      foregroundColor: textColor,
      padding: padding,
      elevation: outlined ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: outlined ? BorderSide(color: buttonColor, width: 1.5) : BorderSide.none,
      ),
      minimumSize: Size(fullWidth ? double.infinity : (width ?? 0), height),
    );

    Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(icon, size: 20),
          ),
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (fullWidth) {
      child = Center(child: child);
    }

    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: buttonStyle,
      child: child,
    );
  }
}