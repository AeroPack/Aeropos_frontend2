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

  double get amount => qty * rate;
}

class InvoiceData {
  String businessName;
  String businessEmail;
  String businessPhone;
  String businessAddress;
  String gstin;
  String clientName;
  String clientAddress;
  String taxLabel;
  double taxRate;
  Color themeColor;
  String fontFamily;
  List<InvoiceItem> items;
  String notes;
  bool isThermal;
  int thermalWidth;
  bool showTaxBreakdown;
  bool showLogo;
  bool showBusinessAddress;
  bool showClientContact;
  bool showNotes;
  String? logoPath;
  String? paymentMethod;

  InvoiceData({
    required this.businessName,
    required this.businessEmail,
    required this.businessPhone,
    required this.businessAddress,
    required this.gstin,
    required this.clientName,
    required this.clientAddress,
    required this.taxLabel,
    required this.taxRate,
    required this.themeColor,
    required this.fontFamily,
    required this.items,
    required this.notes,
    required this.isThermal,
    this.thermalWidth = 80,
    this.showTaxBreakdown = true,
    this.showLogo = true,
    this.showBusinessAddress = true,
    this.showClientContact = false,
    this.showNotes = true,
    this.logoPath,
    this.paymentMethod,
  });

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.amount);
  double get taxAmount => subtotal * (taxRate / 100);
  double get total => subtotal + taxAmount;
}

// --- Mapper Extensions ---
extension SaleMapper on InvoiceData {
  void updateWithSale(dynamic sale) {
    // We'll use dynamic because Sale import might create circular dependencies
    // Alternatively, we just map everything manually in the Checkout flow.
  }
}
