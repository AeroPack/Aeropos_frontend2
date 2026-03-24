import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models.dart';

abstract class InvoiceTemplate {
  String get id;
  String get name;
  String get industry;
  String get format;
  String get styleName;
  String get previewImagePath;
  Color get badgeColor;
  String get metadata;
  String? get tag;
  bool get isThermal => format.toUpperCase() == 'THERMAL';

  pw.Document buildPdf(InvoiceData data);

  Widget buildFlutterPreview(InvoiceData data);

  InvoiceData getDefaultData();

  pw.MemoryImage? getLogoImage(InvoiceData data) {
    if (data.showLogo && data.logoBytes != null) {
      return pw.MemoryImage(data.logoBytes!);
    }
    return null;
  }

  Widget buildLogoWidget(InvoiceData data, {double size = 60}) {
    if (!data.showLogo) return const SizedBox();

    if (data.logoBytes != null) {
      return Image.memory(data.logoBytes!, height: size, width: size);
    }

    if (data.logoPath != null && data.logoPath!.isNotEmpty) {
      return Image.network(data.logoPath!, height: size, width: size);
    }

    return const SizedBox();
  }
}
