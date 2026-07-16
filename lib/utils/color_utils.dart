import 'package:flutter/material.dart';

const Color fallbackProjectColor = Color(0xFF6366F1);

Color parseHexColor(dynamic value, {Color fallback = fallbackProjectColor}) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return fallback;

  var hex = raw
      .replaceFirst('#', '')
      .replaceFirst('0x', '')
      .replaceFirst('0X', '');

  if (hex.length == 6) {
    hex = 'FF$hex';
  }

  if (hex.length != 8 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
    return fallback;
  }

  return Color(int.parse(hex, radix: 16));
}
