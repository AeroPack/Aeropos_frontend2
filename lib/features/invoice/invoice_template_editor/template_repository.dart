import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ezo/core/database/app_database.dart';
import 'package:ezo/core/di/service_locator.dart';
import 'package:ezo/core/providers/tenant_provider.dart';
import 'models.dart';
import 'template_engine/invoice_template.dart';
import 'template_engine/template_registry.dart';

/// Repository responsible for managing invoice template selection and persistence.
class InvoiceTemplateRepository {
  final AppDatabase _db;

  InvoiceTemplateRepository(this._db);

  /// Retrieves the currently selected template for a specific tenant.
  /// Falls back to the default A4 template if none is selected.
  Future<InvoiceTemplate> getSelectedTemplate(int tenantId) async {
    final settings = await (_db.select(_db.invoiceSettings)
          ..where((t) => t.tenantId.equals(tenantId)))
        .getSingleOrNull();

    if (settings == null) {
      return TemplateRegistry.getTemplateById('default_a4');
    }
    return TemplateRegistry.getTemplateById(settings.layout);
  }

  /// Watches the selected template for a specific tenant as a stream.
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

  /// Saves the template selection and customization for a specific tenant.
  Future<void> saveTemplateSelection({
    required int tenantId,
    required String templateId,
    String? accentColorHex,
    String? fontFamily,
    String? logoPath,
    int? thermalWidth,
    bool? showTaxBreakdown,
    bool? showLogo,
    bool? showAddress,
    bool? showCustomerDetails,
    bool? showFooter,
    String? customConfigJson,
  }) async {
    // Check if settings already exist for this tenant
    final existing = await (_db.select(_db.invoiceSettings)
          ..where((t) => t.tenantId.equals(tenantId)))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.invoiceSettings).insert(
            InvoiceSettingsCompanion.insert(
              layout: templateId,
              footerMessage: const Value(''), // Default empty
              accentColor: accentColorHex != null ? Value(accentColorHex) : const Value('#2196F3'),
              fontFamily: fontFamily != null ? Value(fontFamily) : const Value('Inter'),
              logoPath: logoPath != null ? Value(logoPath) : const Value.absent(),
              thermalWidth: thermalWidth != null ? Value(thermalWidth) : const Value(80),
              showTaxBreakdown: showTaxBreakdown != null ? Value(showTaxBreakdown) : const Value(true),
              showLogo: showLogo != null ? Value(showLogo) : const Value(true),
              showAddress: showAddress != null ? Value(showAddress) : const Value(true),
              showCustomerDetails: showCustomerDetails != null ? Value(showCustomerDetails) : const Value(true),
              showFooter: showFooter != null ? Value(showFooter) : const Value(true),
              tenantId: Value(tenantId),
              updatedAt: Value(DateTime.now()),
            ),
          );
    } else {
      await (_db.update(_db.invoiceSettings)
            ..where((t) => t.tenantId.equals(tenantId)))
          .write(
        InvoiceSettingsCompanion(
          layout: Value(templateId),
          accentColor: accentColorHex != null ? Value(accentColorHex) : const Value.absent(),
          fontFamily: fontFamily != null ? Value(fontFamily) : const Value.absent(),
          logoPath: logoPath != null ? Value(logoPath) : const Value.absent(),
          thermalWidth: thermalWidth != null ? Value(thermalWidth) : const Value.absent(),
          showTaxBreakdown: showTaxBreakdown != null ? Value(showTaxBreakdown) : const Value.absent(),
          showLogo: showLogo != null ? Value(showLogo) : const Value.absent(),
          showAddress: showAddress != null ? Value(showAddress) : const Value.absent(),
          showCustomerDetails: showCustomerDetails != null ? Value(showCustomerDetails) : const Value.absent(),
          showFooter: showFooter != null ? Value(showFooter) : const Value.absent(),
          customConfig: customConfigJson != null ? Value(customConfigJson) : const Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  /// Hydrates an InvoiceData object with the real tenant details.
  Future<InvoiceData> getHydratedInvoiceData(int tenantId, String? templateId) async {
    // 1. Fetch Tenant data
    final tenant = await (_db.select(_db.tenants)
          ..where((t) => t.id.equals(tenantId)))
        .getSingleOrNull();

    // 2. Fetch template settings
    final settings = await (_db.select(_db.invoiceSettings)
          ..where((t) => t.tenantId.equals(tenantId)))
        .getSingleOrNull();

    final activeId = templateId ?? settings?.layout ?? 'default_a4';
    final template = TemplateRegistry.getTemplateById(activeId);
    final defaultData = template.getDefaultData();

    // 3. Merge Tenant info with template defaults
    if (tenant != null) {
      defaultData.businessName = tenant.businessName ?? tenant.name;
      defaultData.businessAddress = tenant.businessAddress ?? '';
      defaultData.businessEmail = tenant.email ?? '';
      // data.phone, data.gstin are assumed to be gathered too
      if (tenant.taxId != null) defaultData.gstin = tenant.taxId!;
    }

    // 4. Apply stored customizations
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
    }

    return defaultData;
  }
}

/// Provider for the InvoiceTemplateRepository.
final invoiceTemplateRepositoryProvider = Provider<InvoiceTemplateRepository>((ref) {
  // Use the database instance from ServiceLocator
  return InvoiceTemplateRepository(ServiceLocator.instance.database);
});

/// Provider that gives the current active template instance for the active tenant.
final activeTemplateProvider = StreamProvider<InvoiceTemplate>((ref) {
  final repo = ref.watch(invoiceTemplateRepositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  return repo.watchSelectedTemplate(tenantId);
});
