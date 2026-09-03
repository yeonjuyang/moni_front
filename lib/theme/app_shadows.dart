import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const card = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];

  static const floatingNav = [
    BoxShadow(
      color: Color(0x14102217),
      blurRadius: 24,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color(0x0A102217),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static List<BoxShadow> hero(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.30),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ];
}
