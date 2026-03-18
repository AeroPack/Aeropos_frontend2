import 'package:flutter/material.dart';
// --- Models ---

class Template {
  final String id;
  final String name;
  final String industry;
  final String format;
  final String style;
  final String image;
  final String metadata;
  final String? tag;
  final Color? styleColor;

  Template({
    required this.id,
    required this.name,
    required this.industry,
    required this.format,
    required this.style,
    required this.image,
    required this.metadata,
    this.tag,
    this.styleColor,
  });
}

class InvoiceItem {
  String id;
  String desc;
  String details;
  double qty;
  double rate;

  InvoiceItem({
    required this.id,
    required this.desc,
    required this.details,
    required this.qty,
    required this.rate,
  });
}
