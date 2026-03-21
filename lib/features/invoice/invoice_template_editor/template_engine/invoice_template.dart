import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models.dart'; // Or wherever your InvoiceData, BusinessInfo, etc. lives

abstract class InvoiceTemplate {
  // 1. Metadata for the Selection Screen
  String get id;
  String get name;
  String get industry;
  String get format; // e.g., 'THERMAL', 'A4', 'A5'
  String get styleName;
  String get previewImagePath; // e.g. 'assets/templates/fresh_mart_preview.png'
  Color get badgeColor;
  String get metadata;
  String? get tag;
  bool get isThermal => format.toUpperCase() == 'THERMAL';


  // 2. The implementation for generating the PDF
  pw.Document buildPdf(InvoiceData data);

  // 3. (Optional) Real-time Flutter Widget Preview for the Editor Screen
  Widget buildFlutterPreview(InvoiceData data);

  // 4. Default dummy data for initialization
  InvoiceData getDefaultData();
}
