import 'package:flutter/material.dart';

class CategoryModel {
  final int categoryId;
  final String categoryName;
  final String categoryType; // 'EXPENSE' | 'INCOME'
  final String? iconName;
  final String? iconColor;
  final int sortOrder;

  const CategoryModel({
    required this.categoryId,
    required this.categoryName,
    required this.categoryType,
    this.iconName,
    this.iconColor,
    required this.sortOrder,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      categoryId: (json['categoryId'] as num).toInt(),
      categoryName: json['categoryName'] as String,
      categoryType: json['categoryType'] as String,
      iconName: json['iconName'] as String?,
      iconColor: json['iconColor'] as String?,
      sortOrder: (json['sortOrder'] as num).toInt(),
    );
  }

  IconData get icon => categoryIconMap[iconName] ?? Icons.more_horiz;

  Color get color {
    final hex = iconColor;
    if (hex == null) return const Color(0xFF9E9E9E);
    return parseHexColor(hex);
  }
}

Color parseHexColor(String hex) {
  final clean = hex.replaceAll('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

const Map<String, IconData> categoryIconMap = {
  'restaurant': Icons.restaurant_outlined,
  'coffee': Icons.coffee_outlined,
  'bus': Icons.directions_bus_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'subscription': Icons.subscriptions_outlined,
  'hospital': Icons.local_hospital_outlined,
  'home': Icons.home_outlined,
  'salary': Icons.account_balance_outlined,
  'work': Icons.work_outline,
  'people': Icons.people_outline,
  'sports': Icons.sports_outlined,
  'travel': Icons.flight_outlined,
  'education': Icons.school_outlined,
  'gift': Icons.card_giftcard_outlined,
  'pet': Icons.pets_outlined,
  'other': Icons.more_horiz,
};

const List<String> categoryColorOptions = [
  '#FF6B6B', '#FFB347', '#6BCB77', '#4D96FF',
  '#AD5CFF', '#FF6BAA', '#4DC9D6', '#9E9E9E',
  '#26A69A', '#42A5F5', '#EF5350', '#FFA726',
];
