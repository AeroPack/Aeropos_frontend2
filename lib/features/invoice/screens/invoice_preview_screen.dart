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

class InvoicePreviewScreen extends ConsumerStatefulWidget {
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
  ConsumerState<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen> {
  double _zoomLevel = 0.6; // Scale factor for maxPageWidth

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + 0.1).clamp(0.2, 2.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - 0.1).clamp(0.2, 2.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final templateAsync = ref.watch(activeTemplateProvider);
    final tenantId = ref.watch(tenantIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Preview: ${widget.invoiceEntity.invoiceNumber}"),
        backgroundColor: PosColors.navy,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: _zoomOut,
            tooltip: 'Zoom Out',
          ),
          Center(
            child: Text(
              '${(_zoomLevel * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: _zoomIn,
            tooltip: 'Zoom In',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: templateAsync.when(
        data: (activeTemplate) => PdfPreview(
          // Using maxPageWidth to simulate zoom since directly 'zoom' might not be available or behaves differently
          maxPageWidth: MediaQuery.of(context).size.width * _zoomLevel * 1.5,
          build: (format) async {
            final repo = ref.read(invoiceTemplateRepositoryProvider);
            final invoiceData = await repo.getHydratedInvoiceData(tenantId, null);

            invoiceData.clientName = widget.customer?.name ?? 'Walk-in Customer';
            invoiceData.clientAddress = widget.customer?.address ?? '';
            invoiceData.showClientContact = widget.customer != null;
            
            invoiceData.items = widget.items.map((res) {
              final itemRow = res.readTable(ServiceLocator.instance.database.invoiceItems);
              final productRow = res.readTable(ServiceLocator.instance.database.products);
              
              return editor_models.InvoiceItem(
                id: itemRow.id.toString(),
                desc: productRow.name,
                details: '', 
                qty: itemRow.quantity.toDouble(),
                rate: itemRow.unitPrice,
              );
            }).toList();

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
