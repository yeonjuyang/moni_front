import 'package:flutter/material.dart';

class AssetModel {
  final int assetId;
  final String assetName;
  final String assetType; // CASH | BANK | CARD | OTHER
  final int balance;
  final int sortOrder;

  const AssetModel({
    required this.assetId,
    required this.assetName,
    required this.assetType,
    required this.balance,
    required this.sortOrder,
  });

  factory AssetModel.fromJson(Map<String, dynamic> json) {
    return AssetModel(
      assetId: (json['assetId'] as num).toInt(),
      assetName: json['assetName'] as String,
      assetType: json['assetType'] as String,
      balance: (json['balance'] as num).toInt(),
      sortOrder: (json['sortOrder'] as num).toInt(),
    );
  }

  IconData get icon => assetTypeIcons[assetType] ?? Icons.more_horiz;
  String get typeLabel => assetTypeLabels[assetType] ?? '기타';
}

const Map<String, IconData> assetTypeIcons = {
  'CASH': Icons.money_outlined,
  'BANK': Icons.account_balance_outlined,
  'CARD': Icons.credit_card_outlined,
  'OTHER': Icons.more_horiz,
};

const Map<String, String> assetTypeLabels = {
  'CASH': '현금',
  'BANK': '은행',
  'CARD': '카드',
  'OTHER': '기타',
};

const List<String> assetTypes = ['CASH', 'BANK', 'CARD', 'OTHER'];
