import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:ezo/core/layout/pos_design_system.dart';
import 'package:ezo/core/database/app_database.dart';
import 'package:ezo/core/di/service_locator.dart';
import 'package:drift/drift.dart' show TypedResult;

// Import the new template system
import 'package:ezo/features/invoice/invoice_template_editor/template_repository.dart';
import 'package:ezo/features/invoice/invoice_template_editor/models.dart' as editor_models;
import 'package:ezo/core/providers/tenant_provider.dart';

class InvoicePreviewScreen extends ConsumerWidget {
  final InvoiceEntity invoiceEntity;
  final CustomerEntity? customer;
  final List<TypedResult> items;

  const InvoicePreviewScreen({
    super.key,
    required this.invoiceEntity,
    this.customer,
    required this.items,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch the active template (synced with settings and tenant)
    final templateAsync = ref.watch(activeTemplateProvider);
    final tenantId = ref.watch(tenantIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Preview: ${invoiceEntity.invoiceNumber}"),
        backgroundColor: PosColors.navy,
        foregroundColor: Colors.white,
      ),
      body: templateAsync.when(
        data: (activeTemplate) => PdfPreview(
          build: (format) async {
            final repo = ref.read(invoiceTemplateRepositoryProvider);
            
            // 2. Hydrate template with business/tenant/stored-settings
            final invoiceData = await repo.getHydratedInvoiceData(tenantId, null);

            // 3. Inject transaction-specific data
            invoiceData.clientName = customer?.name ?? 'Walk-in Customer';
            invoiceData.clientAddress = customer?.address ?? '';
            invoiceData.showClientContact = customer != null;
            
            // Use existing invoice date and metadata
            // invoiceData.notes can be set if needed
            
            // 4. Map DB items to the editor's item model
            invoiceData.items = items.map((res) {
              final itemRow = res.readTable(ServiceLocator.instance.database.invoiceItems);
              final productRow = res.readTable(ServiceLocator.instance.database.products);
              
              return editor_models.InvoiceItem(
                id: itemRow.id.toString(),
                desc: productRow.name,
                details: '', // Or product description if exists
                qty: itemRow.quantity.toDouble(),
                rate: itemRow.unitPrice,
              );
            }).toList();

            // 5. Generate PDF using the new engine
            final doc = activeTemplate.buildPdf(invoiceData);
            return doc.save();
          },
          canDebug: false,
          canChangePageFormat: false,
          onPrinted: (context) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Invoice sent to printer")),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Template Error: $err")),
      ),
    );
  }
}
