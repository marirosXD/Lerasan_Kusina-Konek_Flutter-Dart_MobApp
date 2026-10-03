import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class KusinaBrandMark extends StatelessWidget {
  final double fontSize;
  final double iconSize;

  const KusinaBrandMark({super.key, this.fontSize = 22, this.iconSize = 22});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: AppColors.backgroundCream,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.restaurant_menu, color: AppColors.primaryTerracotta, size: iconSize),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, fontFamily: 'sans-serif'),
            children: const [
              TextSpan(text: 'Kusina ', style: TextStyle(color: AppColors.textDarkSlate)),
              TextSpan(text: 'Konek', style: TextStyle(color: AppColors.primaryTerracotta, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}
