import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'models.dart';
import 'package:printing/printing.dart';
import 'template_engine/invoice_template.dart';
import 'template_engine/template_registry.dart';
import 'template_repository.dart';
import 'package:ezo/core/providers/tenant_provider.dart';

class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

class EditorScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final String? templateId;

  const EditorScreen({super.key, required this.onBack, this.templateId});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _ToolbarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ToolbarItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _DeviceIcon extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeviceIcon({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: 20,
        color: isSelected ? Colors.blue : Colors.grey.shade400,
      ),
    );
  }
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  bool isLoading = true;
  late bool isThermal;
  late String businessName;
  late String businessEmail;
  late String businessPhone;
  late String businessAddress;
  late String gstin;
  late String clientName;
  late String clientAddress;
  late String taxLabel;
  late double taxRate;
  late Color themeColor;
  late String fontFamily;
  late List<InvoiceItem> items;
  late String notes;
  String? logoPath;
  late int thermalWidth;
  late bool showTaxBreakdown;
  late bool showLogo;
  late bool showBusinessAddress;
  late bool showClientContact;
  late bool showNotes;

  // Controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _businessEmailController =
      TextEditingController();
  final TextEditingController _businessPhoneController =
      TextEditingController();
  final TextEditingController _businessAddressController =
      TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _clientNameController = TextEditingController();
  final TextEditingController _clientAddressController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _taxRateController = TextEditingController();
  final TextEditingController _taxLabelController = TextEditingController();
  final Map<String, TextEditingController> _itemDescControllers = {};
  final Map<String, TextEditingController> _itemQtyControllers = {};
  final Map<String, TextEditingController> _itemRateControllers = {};

  final Debouncer _previewDebouncer = Debouncer(milliseconds: 300);

  bool isSaving = false;
  bool isSidebarOpen = true;
  String deviceView = 'desktop';
  late InvoiceTemplate activeTemplate;

  // Font configuration - using local fonts
  final List<Map<String, String>> fonts = const [
    {'name': 'Inter', 'family': 'Inter', 'displayName': 'Inter'},
    {'name': 'Roboto', 'family': 'Roboto', 'displayName': 'Roboto'},
    {'name': 'Montserrat', 'family': 'Montserrat', 'displayName': 'Montserrat'},
    {
      'name': 'Playfair Display',
      'family': 'Playfair Display',
      'displayName': 'Playfair',
    },
    {
      'name': 'JetBrains Mono',
      'family': 'JetBrains Mono',
      'displayName': 'Mono',
    },
  ];

  final List<Color> themeColors = const [
    Color(0xFF13a4ec),
    Color(0xFF10b981),
    Color(0xFF4f46e5),
    Color(0xFF1e293b),
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final tenantId = ref.read(tenantIdProvider);
    final repo = ref.read(invoiceTemplateRepositoryProvider);

    try {
      final data = await repo.getHydratedInvoiceData(
        tenantId,
        widget.templateId,
      );

      if (mounted) {
        setState(() {
          activeTemplate = TemplateRegistry.getTemplateById(
            widget.templateId ?? 'default_a4',
          );
          businessName = data.businessName;
          businessEmail = data.businessEmail;
          businessPhone = data.businessPhone;
          businessAddress = data.businessAddress;
          gstin = data.gstin;
          clientName = data.clientName;
          clientAddress = data.clientAddress;
          taxLabel = data.taxLabel;
          taxRate = data.taxRate;
          themeColor = data.themeColor;
          fontFamily = data.fontFamily.isNotEmpty ? data.fontFamily : 'Inter';
          items = data.items;
          notes = data.notes;
          isThermal = data.isThermal;
          logoPath = data.logoPath;
          thermalWidth = data.thermalWidth;
          showTaxBreakdown = data.showTaxBreakdown;
          showLogo = data.showLogo;
          showBusinessAddress = data.showBusinessAddress;
          showClientContact = data.showClientContact;
          showNotes = data.showNotes;

          // Initialize controllers
          _businessNameController.text = businessName;
          _businessEmailController.text = businessEmail;
          _businessPhoneController.text = businessPhone;
          _businessAddressController.text = businessAddress;
          _gstinController.text = gstin;
          _clientNameController.text = clientName;
          _clientAddressController.text = clientAddress;
          _notesController.text = notes;
          _taxRateController.text = taxRate.toString();
          _taxLabelController.text = taxLabel;

          // Initialize item controllers
          for (var item in items) {
            _itemDescControllers[item.id] = TextEditingController(
              text: item.desc,
            );
            _itemQtyControllers[item.id] = TextEditingController(
              text: item.qty.toString(),
            );
            _itemRateControllers[item.id] = TextEditingController(
              text: item.rate.toString(),
            );
          }

          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  @override
  void dispose() {
    _previewDebouncer.dispose();
    _businessNameController.dispose();
    _businessEmailController.dispose();
    _businessPhoneController.dispose();
    _businessAddressController.dispose();
    _gstinController.dispose();
    _clientNameController.dispose();
    _clientAddressController.dispose();
    _notesController.dispose();
    _taxRateController.dispose();
    _taxLabelController.dispose();
    for (var controller in _itemDescControllers.values) controller.dispose();
    for (var controller in _itemQtyControllers.values) controller.dispose();
    for (var controller in _itemRateControllers.values) controller.dispose();
    super.dispose();
  }

  String formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2)}';
  }

  double calculateSubtotal() {
    return items.fold(0, (sum, item) => sum + (item.qty * item.rate));
  }

  double get subtotal => calculateSubtotal();
  double get gst => subtotal * (taxRate / 100);
  double get total => subtotal + gst;

  void addItem() {
    setState(() {
      items.add(
        InvoiceItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          desc: 'New Item',
          details: 'Description here',
          qty: 1,
          rate: 0,
        ),
      );
    });
  }

  void removeItem(String id) {
    setState(() {
      items.removeWhere((item) => item.id == id);
    });
  }

  void updateItem(String id, String field, dynamic value) {
    final index = items.indexWhere((item) => item.id == id);
    if (index != -1) {
      switch (field) {
        case 'desc':
          items[index].desc = value;
          break;
        case 'details':
          items[index].details = value;
          break;
        case 'qty':
          items[index].qty = double.tryParse(value.toString()) ?? 0;
          break;
        case 'rate':
          items[index].rate = double.tryParse(value.toString()) ?? 0;
          break;
      }
    }
  }

  Future<void> _pickLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        logoPath = image.path;
      });
    }
  }

  Future<void> handleSave() async {
    setState(() => isSaving = true);

    try {
      final repo = ref.read(invoiceTemplateRepositoryProvider);
      final tenantId = ref.read(tenantIdProvider);

      await repo.saveTemplateSelection(
        tenantId: tenantId,
        templateId: activeTemplate.id,
        accentColorHex:
            '#${themeColor.value.toRadixString(16).padLeft(8, '0')}',
        fontFamily: fontFamily,
        logoPath: logoPath,
        thermalWidth: thermalWidth,
        showTaxBreakdown: showTaxBreakdown,
        showLogo: showLogo,
        showAddress: showBusinessAddress,
        showCustomerDetails: showClientContact,
        showFooter: showNotes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template settings linked and saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error linking template: $e')));
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }

    widget.onBack();
  }

  Future<void> exportPDF() async {
    try {
      final invoiceData = InvoiceData(
        businessName: businessName,
        businessEmail: businessEmail,
        businessPhone: businessPhone,
        businessAddress: businessAddress,
        gstin: gstin,
        clientName: clientName,
        clientAddress: clientAddress,
        taxLabel: taxLabel,
        taxRate: taxRate,
        themeColor: themeColor,
        fontFamily: fontFamily,
        items: items
            .map(
              (i) => InvoiceItem(
                id: i.id,
                desc: i.desc,
                details: i.details,
                qty: i.qty,
                rate: i.rate,
              ),
            )
            .toList(),
        notes: notes,
        isThermal: isThermal,
        logoPath: logoPath,
        thermalWidth: thermalWidth,
        showTaxBreakdown: showTaxBreakdown,
        showLogo: showLogo,
        showBusinessAddress: showBusinessAddress,
        showClientContact: showClientContact,
        showNotes: showNotes,
      );

      final pdf = activeTemplate.buildPdf(invoiceData);
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to generate PDF')));
      }
    }
  }

  // Helper method to get the actual font family name
  String _getFontFamily(String fontName) {
    final font = fonts.firstWhere(
      (f) => f['name'] == fontName,
      orElse: () => fonts.first,
    );
    return font['family'] ?? 'Inter';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildEditorHeader(),
            _buildEditorToolbar(),
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      if (isSidebarOpen) _buildSidebar(),
                      Expanded(child: _buildPreview()),
                    ],
                  ),
                  if (isSidebarOpen && MediaQuery.of(context).size.width < 1024)
                    _buildSidebarOverlay(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 24),
            color: Colors.grey.shade700,
            tooltip: 'Back',
            padding: const EdgeInsets.all(12),
          ),
          if (!isMobile) ...[
            Container(height: 24, width: 1, color: Colors.grey.shade200),
            const SizedBox(width: 8),
            Text(
              'Professional Services',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ],
          const Spacer(),
          if (!isMobile) ...[
            TextButton(onPressed: () {}, child: const Text('Reset')),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: exportPDF,
              icon: const Icon(Icons.download, size: 16),
              label: const Text('PDF'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
            ),
          ] else
            IconButton(
              onPressed: exportPDF,
              icon: const Icon(Icons.download, color: Colors.blue),
              tooltip: 'Export PDF',
            ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 24,
                vertical: 8,
              ),
            ),
            child: Text(
              isSaving ? '...' : (isMobile ? 'Save' : 'Save Template'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.dashboard_outlined, color: Colors.blue),
              onPressed: () => context.go('/dashboard'),
            ),
          ],
        ],
      ),
    );
  }

  void _onFontSelected(String fontName) {
    setState(() {
      fontFamily = fontName;
    });
  }

  Widget _buildEditorToolbar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade100),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (MediaQuery.of(context).size.width < 1024)
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => setState(() => isSidebarOpen = !isSidebarOpen),
              ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _pickLogo,
              child: const _ToolbarItem(
                icon: Icons.cloud_upload_outlined,
                label: 'Logo',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Row(
              children: themeColors.map((color) {
                return GestureDetector(
                  onTap: () => setState(() => themeColor = color),
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: themeColor == color
                          ? Border.all(color: Colors.blue, width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 16),
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: fonts.map((font) {
                  final isSelected = fontFamily == font['name'];
                  return GestureDetector(
                    onTap: () => _onFontSelected(font['name']!),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          font['displayName']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontFamily: _getFontFamily(font['name']!),
                            color: isSelected
                                ? Colors.blue
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: 16),
            Row(
              children: [
                _DeviceIcon(
                  icon: Icons.desktop_windows,
                  isSelected: deviceView == 'desktop',
                  onTap: () {
                    setState(() {
                      deviceView = 'desktop';
                      isThermal = false;
                    });
                  },
                ),
                const SizedBox(width: 12),
                _DeviceIcon(
                  icon: Icons.tablet_android,
                  isSelected: deviceView == 'tablet',
                  onTap: () {
                    setState(() {
                      deviceView = 'tablet';
                      isThermal = false;
                    });
                  },
                ),
                const SizedBox(width: 12),
                _DeviceIcon(
                  icon: Icons.phone_android,
                  isSelected: deviceView == 'mobile',
                  onTap: () {
                    setState(() {
                      deviceView = 'mobile';
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth < 1024 ? screenWidth * 0.85 : 400.0;

    return Container(
      width: sidebarWidth,
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSidebarSection(
              title: '1. Business & Client Content',
              icon: Icons.info_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Business Logo'),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickLogo,
                    child: Container(
                      height: 80,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: logoPath != null
                          ? Stack(
                              children: [
                                Center(
                                  child: Image.file(
                                    File(logoPath!),
                                    height: 60,
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, size: 16),
                                    onPressed: () {
                                      setState(() => logoPath = null);
                                    },
                                  ),
                                ),
                              ],
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Upload Business Logo',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Business Info'),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Business Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      businessName = value;
                      _previewDebouncer.run(() => setState(() {}));
                    },
                    controller: _businessNameController,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            businessEmail = value;
                            _previewDebouncer.run(() => setState(() {}));
                          },
                          controller: _businessEmailController,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Phone',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            businessPhone = value;
                            _previewDebouncer.run(() => setState(() {}));
                          },
                          controller: _businessPhoneController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (value) {
                      businessAddress = value;
                      _previewDebouncer.run(() => setState(() {}));
                    },
                    controller: _businessAddressController,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'GSTIN',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      gstin = value;
                      _previewDebouncer.run(() => setState(() {}));
                    },
                    controller: _gstinController,
                  ),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Client Info'),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Client Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      clientName = value;
                      _previewDebouncer.run(() => setState(() {}));
                    },
                    controller: _clientNameController,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Client Address',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (value) {
                      clientAddress = value;
                      _previewDebouncer.run(() => setState(() {}));
                    },
                    controller: _clientAddressController,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildSidebarSection(
              title: '2. Line Items',
              icon: Icons.list_alt,
              initiallyExpanded: false,
              child: Column(
                children: [
                  ...items.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            decoration: const InputDecoration(
                              hintText: 'Description',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              updateItem(item.id, 'desc', value);
                              _previewDebouncer.run(() => setState(() {}));
                            },
                            controller: _itemDescControllers[item.id] ??=
                                TextEditingController(text: item.desc),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Qty',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    updateItem(item.id, 'qty', value);
                                    _previewDebouncer.run(
                                      () => setState(() {}),
                                    );
                                  },
                                  controller: _itemQtyControllers[item.id] ??=
                                      TextEditingController(
                                        text: item.qty.toString(),
                                      ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Rate',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    updateItem(item.id, 'rate', value);
                                    _previewDebouncer.run(
                                      () => setState(() {}),
                                    );
                                  },
                                  controller: _itemRateControllers[item.id] ??=
                                      TextEditingController(
                                        text: item.rate.toString(),
                                      ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          formatCurrency(item.qty * item.rate),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                        ),
                                        onPressed: () => removeItem(item.id),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: addItem,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade200,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Add Item',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (activeTemplate.isThermal)
              _buildSidebarSection(
                title: '3. Printer Settings',
                icon: Icons.print_outlined,
                initiallyExpanded: true,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Printer Width',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 58, label: Text('58mm')),
                            ButtonSegment(value: 80, label: Text('80mm')),
                          ],
                          selected: {thermalWidth},
                          onSelectionChanged: (val) =>
                              setState(() => thermalWidth = val.first),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _buildSidebarSection(
              title: '4. Pricing & Tax',
              icon: Icons.credit_card,
              initiallyExpanded: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Show Tax Breakdown',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: showTaxBreakdown,
                        onChanged: (val) =>
                            setState(() => showTaxBreakdown = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tax Label',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                taxLabel = value;
                                _previewDebouncer.run(() => setState(() {}));
                              },
                              controller: _taxLabelController,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tax (%)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                taxRate = double.tryParse(value) ?? 0;
                                _previewDebouncer.run(() => setState(() {}));
                              },
                              controller: _taxRateController,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildSidebarSection(
              title: '5. Notes & Terms',
              icon: Icons.description,
              initiallyExpanded: false,
              child: TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Add warranty terms, payment notes, etc.',
                ),
                maxLines: 5,
                onChanged: (value) {
                  notes = value;
                  _previewDebouncer.run(() => setState(() {}));
                },
                controller: _notesController,
              ),
            ),
            const SizedBox(height: 8),
            _buildSidebarSection(
              title: '6. Visibility Controls',
              icon: Icons.visibility,
              initiallyExpanded: false,
              child: Column(
                children: [
                  _buildCheckboxItem(
                    'Show Logo',
                    showLogo,
                    (v) => setState(() => showLogo = v),
                  ),
                  _buildCheckboxItem(
                    'Business Address',
                    showBusinessAddress,
                    (v) => setState(() => showBusinessAddress = v),
                  ),
                  _buildCheckboxItem(
                    'Client Contact Person',
                    showClientContact,
                    (v) => setState(() => showClientContact = v),
                  ),
                  _buildCheckboxItem(
                    'Notes & Comments',
                    showNotes,
                    (v) => setState(() => showNotes = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildSidebarSection(
              title: '7. Advanced Settings',
              icon: Icons.settings,
              initiallyExpanded: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Page Setup',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: 'A4 Paper',
                              items: const [
                                DropdownMenuItem(
                                  value: 'A4 Paper',
                                  child: Text('A4 Paper'),
                                ),
                              ],
                              onChanged: null,
                              isExpanded: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: 'Portrait',
                              items: const [
                                DropdownMenuItem(
                                  value: 'Portrait',
                                  child: Text('Portrait'),
                                ),
                              ],
                              onChanged: null,
                              isExpanded: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarSection({
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.all(16),
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon, size: 16, color: Colors.blue),
          title: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          children: [child],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade400,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCheckboxItem(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          activeColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildSidebarOverlay() {
    return GestureDetector(
      onTap: () => setState(() => isSidebarOpen = false),
      child: Container(color: Colors.grey.shade900.withValues(alpha: 0.2)),
    );
  }

  Widget _buildPreview() {
    double previewWidth;
    double previewScale = 1.0;

    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth * 0.8;

    switch (deviceView) {
      case 'mobile':
        previewWidth = isThermal ? 300 : 375;
        previewScale = (screenWidth * 0.8) / previewWidth;
        break;
      case 'tablet':
        previewWidth = isThermal ? 300 : 600;
        previewScale = (screenWidth * 0.8) / previewWidth;
        break;
      case 'desktop':
      default:
        previewWidth = isThermal ? 300 : 800;
        previewScale = 1.0;
    }

    previewScale = (availableWidth / previewWidth).clamp(0.3, 1.0);

    return Container(
      color: Colors.grey.shade200,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Transform.scale(
            scale: previewScale,
            child: Container(
              width: previewWidth,
              constraints: BoxConstraints(
                minHeight: isThermal ? 600 : 1123,
                maxHeight: isThermal ? 600 : double.infinity,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              padding: EdgeInsets.all(isThermal ? 24 : 48),
              child: Theme(
                data: Theme.of(context).copyWith(
                  textTheme: Theme.of(context).textTheme.apply(
                        fontFamily: _getFontFamily(fontFamily),
                      ),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(fontFamily: _getFontFamily(fontFamily)),
                  child: activeTemplate.buildFlutterPreview(
                    InvoiceData(
                      businessName: businessName,
                      businessEmail: businessEmail,
                      businessPhone: businessPhone,
                      businessAddress: businessAddress,
                      gstin: gstin,
                      clientName: clientName,
                      clientAddress: clientAddress,
                      taxLabel: taxLabel,
                      taxRate: taxRate,
                      themeColor: themeColor,
                      fontFamily: _getFontFamily(fontFamily),
                      items: items
                          .map(
                            (i) => InvoiceItem(
                              id: i.id,
                              desc: i.desc,
                              details: i.details,
                              qty: i.qty,
                              rate: i.rate,
                            ),
                          )
                          .toList(),
                      notes: notes,
                      isThermal: isThermal,
                      logoPath: logoPath,
                      thermalWidth: thermalWidth,
                      showTaxBreakdown: showTaxBreakdown,
                      showLogo: showLogo,
                      showBusinessAddress: showBusinessAddress,
                      showClientContact: showClientContact,
                      showNotes: showNotes,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
