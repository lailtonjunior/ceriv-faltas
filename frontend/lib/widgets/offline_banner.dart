import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  final String? message;
  final Color backgroundColor;
  final Color textColor;
  final double height;
  final IconData icon;

  const OfflineBanner({
    Key? key,
    this.message,
    this.backgroundColor = Colors.redAccent,
    this.textColor = Colors.white,
    this.height = 40.0,
    this.icon = Icons.cloud_off,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: backgroundColor,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: textColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              message ?? 'Você está offline. Algumas funcionalidades podem estar limitadas.',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}