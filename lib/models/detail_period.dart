import 'package:flutter/material.dart';

enum DetailPeriodMode { monthly, yearly, custom }

class DetailPeriod {
  final DetailPeriodMode mode;
  final DateTime date;
  final DateTimeRange? range;

  const DetailPeriod({required this.mode, required this.date, this.range});
}
