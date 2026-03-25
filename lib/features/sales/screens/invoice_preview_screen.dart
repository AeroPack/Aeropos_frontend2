import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class InvoicePreviewScreen extends StatefulWidget {
  final Future<Uint8List> Function(PdfPageFormat) onLayout;
  final String invoiceNumber;
  final VoidCallback onPrintComplete;

  const InvoicePreviewScreen({
    super.key,
    required this.onLayout,
    required this.invoiceNumber,
    required this.onPrintComplete,
  });

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  double _zoomFactor = 0.5; // Start zoomed out

  void _zoomIn() {
    setState(() {
      _zoomFactor = (_zoomFactor + 0.1).clamp(0.2, 2.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomFactor = (_zoomFactor - 0.1).clamp(0.2, 2.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 800,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Invoice Preview",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_out, size: 20),
                      onPressed: _zoomOut,
                      tooltip: 'Zoom Out',
                    ),
                    Text(
                      '${(_zoomFactor * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in, size: 20),
                      onPressed: _zoomIn,
                      tooltip: 'Zoom In',
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            
            // --- BODY (PDF Preview) ---
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PdfPreview(
                  key: ValueKey('preview_$_zoomFactor'),
                  build: widget.onLayout,
                  allowPrinting: false, 
                  allowSharing: false,
                  canChangePageFormat: false,
                  useActions: false, 
                  initialPageFormat: PdfPageFormat.a4,
                  maxPageWidth: 1000 * _zoomFactor,
                  onPrinted: (context) => widget.onPrintComplete(),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            const Divider(),
            
            // --- FOOTER ---
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    onPressed: () async {
                      final pdf = await widget.onLayout(PdfPageFormat.a4);
                      await Printing.sharePdf(bytes: pdf, filename: 'Invoice_${widget.invoiceNumber}.pdf');
                    },
                    icon: const Icon(Icons.download, size: 20),
                    label: const Text("Download PDF", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      final pdf = await widget.onLayout(PdfPageFormat.a4);
                      await Printing.layoutPdf(
                        name: 'Invoice_${widget.invoiceNumber}',
                        onLayout: (PdfPageFormat format) async => pdf,
                      );
                      widget.onPrintComplete();
                    },
                    icon: const Icon(Icons.print, size: 20),
                    label: const Text("Print Invoice", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
