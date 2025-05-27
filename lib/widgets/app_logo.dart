import 'package:flutter/material.dart';
import '../config/theme.dart';

class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({Key? key, this.size = 80}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size / 2,
      child: Stack(
        children: [
          // Left circle (pink)
          Positioned(
            left: 0,
            child: Container(
              width: size / 2,
              height: size / 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.logoLeftColor,
              ),
            ),
          ),
          // Right circle (blue)
          Positioned(
            right: 0,
            child: Container(
              width: size / 2,
              height: size / 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.logoRightColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}