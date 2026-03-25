import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/core/database/app_database.dart';
import 'package:ezo/core/di/service_locator.dart';
import 'package:ezo/core/providers/tenant_provider.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'template_engine/invoice_template.dart';
import 'template_engine/template_registry.dart';

class InvoiceTemplateRepository {
  final AppDatabase _db;

  InvoiceTemplateRepository(this._db);

  Future<InvoiceTemplate> getSelectedTemplate(int tenantId) async {
    final settings = await (_db.select(
      _db.invoiceSettings,
    )..where((t) => t.tenantId.equals(tenantId))).getSingleOrNull();

    if (settings == null) {
      return TemplateRegistry.getTemplateById('default_a4');
    }
    return TemplateRegistry.getTemplateById(settings.layout);
  }

  Stream<InvoiceTemplate> watchSelectedTemplate(int tenantId) {
    return (_db.select(_db.invoiceSettings)
          ..where((t) => t.tenantId.equals(tenantId)))
        .watchSingleOrNull()
        .map((settings) {
          if (settings == null) {
            return TemplateRegistry.getTemplateById('default_a4');
          }
          return TemplateRegistry.getTemplateById(settings.layout);
        });
  }

  Future<void> saveTemplateSelection({
    required int tenantId,
    required String templateId,
    String? accentColorHex,
    String? fontFamily,
    String? logoPath, // This should now be the server URL, not local path
    int? thermalWidth,
    bool? showTaxBreakdown,
    bool? showLogo,
    bool? showAddress,
    bool? showCustomerDetails,
    bool? showFooter,
    String? customConfigJson,
  }) async {
    final existing = await (_db.select(
      _db.invoiceSettings,
    )..where((t) => t.tenantId.equals(tenantId))).getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.invoiceSettings)
          .insert(
            InvoiceSettingsCompanion.insert(
              layout: templateId,
              footerMessage: const Value(''),
              accentColor: accentColorHex != null
                  ? Value(accentColorHex)
                  : const Value('#2196F3'),
              fontFamily: fontFamily != null
                  ? Value(fontFamily)
                  : const Value('Inter'),
              logoPath: logoPath != null
                  ? Value(logoPath)
                  : const Value.absent(),
              thermalWidth: thermalWidth != null
                  ? Value(thermalWidth)
                  : const Value(80),
              showTaxBreakdown: showTaxBreakdown != null
                  ? Value(showTaxBreakdown)
                  : const Value(true),
              showLogo: showLogo != null ? Value(showLogo) : const Value(true),
              showAddress: showAddress != null
                  ? Value(showAddress)
                  : const Value(true),
              showCustomerDetails: showCustomerDetails != null
                  ? Value(showCustomerDetails)
                  : const Value(true),
              showFooter: showFooter != null
                  ? Value(showFooter)
                  : const Value(true),
              tenantId: Value(tenantId),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } else {
      await (_db.update(
        _db.invoiceSettings,
      )..where((t) => t.tenantId.equals(tenantId))).write(
        InvoiceSettingsCompanion(
          layout: Value(templateId),
          accentColor: accentColorHex != null
              ? Value(accentColorHex)
              : const Value.absent(),
          fontFamily: fontFamily != null
              ? Value(fontFamily)
              : const Value.absent(),
          logoPath: logoPath != null ? Value(logoPath) : const Value.absent(),
          thermalWidth: thermalWidth != null
              ? Value(thermalWidth)
              : const Value.absent(),
          showTaxBreakdown: showTaxBreakdown != null
              ? Value(showTaxBreakdown)
              : const Value.absent(),
          showLogo: showLogo != null ? Value(showLogo) : const Value.absent(),
          showAddress: showAddress != null
              ? Value(showAddress)
              : const Value.absent(),
          showCustomerDetails: showCustomerDetails != null
              ? Value(showCustomerDetails)
              : const Value.absent(),
          showFooter: showFooter != null
              ? Value(showFooter)
              : const Value.absent(),
          customConfig: customConfigJson != null
              ? Value(customConfigJson)
              : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  Future<InvoiceData> getHydratedInvoiceData(
    int tenantId,
    String? templateId,
  ) async {
    final tenant = await (_db.select(
      _db.tenants,
    )..where((t) => t.id.equals(tenantId))).getSingleOrNull();

    final settings = await (_db.select(
      _db.invoiceSettings,
    )..where((t) => t.tenantId.equals(tenantId))).getSingleOrNull();

    final activeId = templateId ?? settings?.layout ?? 'default_a4';
    final template = TemplateRegistry.getTemplateById(activeId);
    final defaultData = template.getDefaultData();

    if (tenant != null) {
      defaultData.businessName = tenant.businessName ?? tenant.name;
      defaultData.businessAddress = tenant.businessAddress ?? '';
      defaultData.businessEmail = tenant.email ?? '';
      if (tenant.taxId != null) defaultData.gstin = tenant.taxId!;
    }

    if (settings != null) {
      if (settings.accentColor.startsWith('#')) {
        final hexColor = settings.accentColor.replaceAll('#', '0xFF');
        defaultData.themeColor = Color(int.parse(hexColor));
      }
      defaultData.fontFamily = settings.fontFamily;
      defaultData.logoPath = settings.logoPath;
      defaultData.thermalWidth = settings.thermalWidth;
      defaultData.showTaxBreakdown = settings.showTaxBreakdown;
      defaultData.showLogo = settings.showLogo;
      defaultData.showBusinessAddress = settings.showAddress;
      defaultData.showClientContact = settings.showCustomerDetails;
      defaultData.showNotes = settings.showFooter;

      // Fetch logo bytes so PDF generation works (buildPdf is sync and can't do HTTP)
      if (settings.showLogo &&
          settings.logoPath != null &&
          settings.logoPath!.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(settings.logoPath!));
          if (response.statusCode == 200) {
            defaultData.logoBytes = response.bodyBytes;
          }
        } catch (_) {
          // Logo fetch failed — PDF will be generated without logo
        }
      }
    }

    return defaultData;
  }
}

final invoiceTemplateRepositoryProvider = Provider<InvoiceTemplateRepository>((
  ref,
) {
  return InvoiceTemplateRepository(ServiceLocator.instance.database);
});

final activeTemplateProvider = StreamProvider<InvoiceTemplate>((ref) {
  final repo = ref.watch(invoiceTemplateRepositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  return repo.watchSelectedTemplate(tenantId);
});
