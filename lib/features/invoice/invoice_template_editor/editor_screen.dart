import 'package:flutter/material.dart';
import 'models.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;

class EditorScreen extends StatefulWidget {
  final VoidCallback onBack;
  final String? templateId;

  const EditorScreen({super.key, required this.onBack, this.templateId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
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
            color: color.withOpacity(0.1),
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

class _EditorScreenState extends State<EditorScreen> {
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

  bool isSidebarOpen = true;
  String deviceView = 'desktop';
  bool isSaving = false;

  final List<Map<String, String>> fonts = [
    {'name': 'Inter', 'family': 'Inter'},
    {'name': 'Roboto', 'family': 'Roboto'},
    {'name': 'Montserrat', 'family': 'Montserrat'},
    {'name': 'Playfair', 'family': 'Playfair Display'},
    {'name': 'Mono', 'family': 'JetBrains Mono'},
  ];

  final List<Color> themeColors = [
    const Color(0xFF13a4ec),
    const Color(0xFF10b981),
    const Color(0xFF4f46e5),
    const Color(0xFF1e293b),
  ];

  @override
  void initState() {
    super.initState();
    isThermal = ['2', '6', '8', '9', '10', '11'].contains(widget.templateId);
    _initializeData();
  }

  void _initializeData() {
    if (widget.templateId == '10') {
      businessName = "Fresh Mart Grocery";
      businessEmail = "info@freshmart.com";
      businessPhone = "+91 22 9876 5432";
      businessAddress = "123 Market Street, Downtown, City, State - 400001";
      gstin = "27AABCF1234Z1Z5";
      clientName = "Walk-in Customer";
      clientAddress = "Local Area";
      taxLabel = "GST";
      taxRate = 18;
      themeColor = Colors.black;
      fontFamily = "Mono";
      items = [
        InvoiceItem(
          id: '1',
          desc: 'Basmati Rice (Gold)',
          details: 'SKU: 1002',
          qty: 5,
          rate: 90,
        ),
        InvoiceItem(
          id: '2',
          desc: 'Amul Butter 500g',
          details: 'SKU: 4051',
          qty: 2,
          rate: 255,
        ),
        InvoiceItem(
          id: '3',
          desc: 'Fresh Tomato',
          details: 'SKU: 0021',
          qty: 1.5,
          rate: 40,
        ),
        InvoiceItem(
          id: '4',
          desc: 'Sugar Crystal',
          details: 'SKU: 1088',
          qty: 2,
          rate: 45,
        ),
      ];
      notes =
          "SAVE PAPER - GO GREEN\nGST AMOUNT INCLUDED IN MRP WHERE APPLICABLE\nNO RETURNS WITHOUT VALID BILL\nEXCHANGE WITHIN 24HRS FOR PERISHABLES";
    } else if (widget.templateId == '11') {
      businessName = "The Cozy Corner Cafe";
      businessEmail = "hello@cozycorner.cafe";
      businessPhone = "+1 (555) 012-3456";
      businessAddress = "123 Brew Street, Coffee District";
      gstin = "CAF-8821-USA";
      clientName = "Table #12";
      clientAddress = "Dine-in";
      taxLabel = "GST";
      taxRate = 18;
      themeColor = Colors.black;
      fontFamily = "Mono";
      items = [
        InvoiceItem(
          id: '1',
          desc: 'Caramel Macchiato (L)',
          details: 'Extra Shot',
          qty: 1,
          rate: 450,
        ),
        InvoiceItem(
          id: '2',
          desc: 'Avocado Sourdough',
          details: 'With Poached Egg',
          qty: 2,
          rate: 850,
        ),
        InvoiceItem(
          id: '3',
          desc: 'Blueberry Muffin',
          details: 'Freshly Baked',
          qty: 1,
          rate: 250,
        ),
      ];
      notes = "Enjoy your meal!\nThank you for visiting us.\nVisit again!";
    } else {
      businessName = isThermal
          ? "ElectroTech Solutions"
          : "Design Systems India Pvt. Ltd.";
      businessEmail = isThermal
          ? "contact@electrotech.com"
          : "billing@dsindia.in";
      businessPhone = isThermal ? "+91 80 1234 5678" : "+91 98765 43210";
      businessAddress = isThermal
          ? "123 Silicon Valley Road, Tech Park, Bangalore, KA - 560001"
          : "402, Business Hub, BKC, Mumbai, Maharashtra 400051";
      gstin = isThermal ? "29AAAAA0000A1Z5" : "27AAAAA0000A1Z5";
      clientName = isThermal ? "Walk-in Customer" : "Global Tech Solutions";
      clientAddress = isThermal
          ? "Bangalore, India"
          : "12th Floor, Prestige Tech Park, Bangalore, KA 560103";
      taxLabel = "GST";
      taxRate = 18;
      themeColor = isThermal ? Colors.black : const Color(0xFF13a4ec);
      fontFamily = isThermal ? "Mono" : "Inter";
      if (isThermal) {
        items = [
          InvoiceItem(
            id: '1',
            desc: 'Logitech MX Master 3S',
            details: 'SN: MX29384756',
            qty: 1,
            rate: 8500,
          ),
          InvoiceItem(
            id: '2',
            desc: 'USB-C Hub 7-in-1',
            details: 'SN: UH992102',
            qty: 2,
            rate: 1200,
          ),
        ];
        notes =
            "Warranty Terms:\n1. 1-year manufacturer warranty from date of invoice.\n2. Physical damage or water exposure voids warranty.";
      } else {
        items = [
          InvoiceItem(
            id: '1',
            desc: 'UI/UX Design - Dashboard',
            details: 'High-fidelity prototypes for admin panel',
            qty: 40,
            rate: 1200,
          ),
          InvoiceItem(
            id: '2',
            desc: 'React Implementation',
            details: 'Frontend components development',
            qty: 25,
            rate: 1500,
          ),
        ];
        notes =
            "Please include the invoice number in your bank transfer description. Payment is due within 15 days of the invoice date. GST is applicable as per Indian tax laws. Thank you for your business!";
      }
    }
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
    setState(() {
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
    });
  }

  Future<void> handleSave() async {
    setState(() => isSaving = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template saved successfully!')),
      );
    }
  }

  Future<void> exportPDF() async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(child: pw.Text('Invoice PDF Export')),
        ),
      );
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to generate PDF')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
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
    );
  }

  Widget _buildEditorHeader() {
    return Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onBack,
            child: Row(
              children: [
                const Icon(Icons.arrow_back, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 24,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.grey.shade200,
          ),
          Text(
            'Professional Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Reset'),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: exportPDF,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: BorderSide(color: Colors.blue.shade100),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Print'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            ),
            child: Text(isSaving ? 'Saving...' : 'Save Template'),
          ),
          const SizedBox(width: 16),
          Container(height: 40, width: 1, color: Colors.grey.shade200),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Powered by',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                ),
              ),
              Text(
                'InvoiceGenius',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description, color: Colors.blue, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorToolbar() {
    return Container(
      height: 48,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width < 1024)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => setState(() => isSidebarOpen = !isSidebarOpen),
            ),
          const SizedBox(width: 32),
          _ToolbarItem(
            icon: Icons.cloud_upload_outlined,
            label: 'Logo',
            color: Colors.blue,
          ),
          const SizedBox(width: 24),
          Row(
            children: [
              ...themeColors.map(
                (color) => GestureDetector(
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
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
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
                  onTap: () => setState(() => fontFamily = font['name']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        font['name']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
          const Spacer(),
          Row(
            children: [
              _DeviceIcon(
                icon: Icons.desktop_windows,
                isSelected: deviceView == 'desktop',
                onTap: () => setState(() => deviceView = 'desktop'),
              ),
              const SizedBox(width: 16),
              _DeviceIcon(
                icon: Icons.tablet_android,
                isSelected: deviceView == 'tablet',
                onTap: () => setState(() => deviceView = 'tablet'),
              ),
              const SizedBox(width: 16),
              _DeviceIcon(
                icon: Icons.phone_android,
                isSelected: deviceView == 'mobile',
                onTap: () => setState(() => deviceView = 'mobile'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 400,
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
                  _buildSectionHeader('Business Info'),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Business Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => businessName = value),
                    controller: TextEditingController(text: businessName),
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
                          onChanged: (value) =>
                              setState(() => businessEmail = value),
                          controller: TextEditingController(
                            text: businessEmail,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Phone',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) =>
                              setState(() => businessPhone = value),
                          controller: TextEditingController(
                            text: businessPhone,
                          ),
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
                    onChanged: (value) =>
                        setState(() => businessAddress = value),
                    controller: TextEditingController(text: businessAddress),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'GSTIN',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => gstin = value),
                    controller: TextEditingController(text: gstin),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionHeader('Client Info'),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Client Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => clientName = value),
                    controller: TextEditingController(text: clientName),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Client Address',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                    onChanged: (value) => setState(() => clientAddress = value),
                    controller: TextEditingController(text: clientAddress),
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
                            onChanged: (value) =>
                                updateItem(item.id, 'desc', value),
                            controller: TextEditingController(text: item.desc),
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
                                  onChanged: (value) =>
                                      updateItem(item.id, 'qty', value),
                                  controller: TextEditingController(
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
                                  onChanged: (value) =>
                                      updateItem(item.id, 'rate', value),
                                  controller: TextEditingController(
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
            _buildSidebarSection(
              title: '3. Pricing & Tax',
              icon: Icons.credit_card,
              initiallyExpanded: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Calculate GST',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
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
                              onChanged: (value) =>
                                  setState(() => taxLabel = value),
                              controller: TextEditingController(text: taxLabel),
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
                              onChanged: (value) => setState(() {
                                taxRate = double.tryParse(value) ?? 0;
                              }),
                              controller: TextEditingController(
                                text: taxRate.toString(),
                              ),
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
              title: '4. Notes & Terms',
              icon: Icons.description,
              initiallyExpanded: false,
              child: TextField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Add warranty terms, payment notes, etc.',
                ),
                maxLines: 5,
                onChanged: (value) => setState(() => notes = value),
                controller: TextEditingController(text: notes),
              ),
            ),
            const SizedBox(height: 8),
            _buildSidebarSection(
              title: '4. Visibility Controls',
              icon: Icons.visibility,
              initiallyExpanded: false,
              child: Column(
                children: [
                  _buildCheckboxItem('Show Logo', true),
                  _buildCheckboxItem('Business Address', true),
                  _buildCheckboxItem('Client Contact Person', false),
                  _buildCheckboxItem('Notes & Comments', true),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildSidebarSection(
              title: '5. Advanced Settings',
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
                              items: [
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
                              items: [
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

  Widget _buildCheckboxItem(String label, bool defaultValue) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        Checkbox(
          value: defaultValue,
          onChanged: (value) {},
          activeColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildSidebarOverlay() {
    return GestureDetector(
      onTap: () => setState(() => isSidebarOpen = false),
      child: Container(color: Colors.grey.shade900.withOpacity(0.2)),
    );
  }

  Widget _buildPreview() {
    double width;
    double scale = 1.0;

    if (deviceView == 'desktop') {
      width = 800;
    } else if (deviceView == 'tablet') {
      width = 768;
      scale = 0.85;
    } else {
      width = 375;
      scale = MediaQuery.of(context).size.width < 600 ? 0.45 : 0.6;
    }

    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: SingleChildScrollView(
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: isThermal ? 300 : width,
              constraints: isThermal
                  ? const BoxConstraints(minHeight: 600)
                  : const BoxConstraints(minHeight: 1123),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: EdgeInsets.all(
                isThermal ? 24 : (deviceView == 'mobile' ? 32 : 48),
              ),
              child: isThermal
                  ? _buildThermalPreview()
                  : _buildStandardPreview(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThermalPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Center(
              child: Text(
                'LOGO',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          businessName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(businessAddress, style: const TextStyle(fontSize: 10)),
        Text(
          '$taxLabel IN: $gstin',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          color: Colors.black,
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: const TextStyle(fontSize: 10),
            ),
            Text(
              'Time: ${DateTime.now().hour}:${DateTime.now().minute}',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Inv No: ET-88291', style: TextStyle(fontSize: 10)),
            const Text('Cashier: Admin', style: TextStyle(fontSize: 10)),
          ],
        ),
        Container(
          height: 1,
          color: Colors.black,
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          children: [
            const TableRow(
              children: [
                Text(
                  'Item',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Qty',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Rate',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
                Text(
                  'Amt',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            ...items.map(
              (item) => TableRow(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.desc, style: const TextStyle(fontSize: 10)),
                      Text(
                        item.details,
                        style: const TextStyle(
                          fontSize: 8,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item.qty.toString(),
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    item.rate.toString(),
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                  Text(
                    (item.qty * item.rate).toString(),
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(
          height: 1,
          color: Colors.black,
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal:', style: TextStyle(fontSize: 10)),
            Text(subtotal.toString(), style: const TextStyle(fontSize: 10)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tax ($taxRate%):', style: const TextStyle(fontSize: 10)),
            Text(gst.toString(), style: const TextStyle(fontSize: 10)),
          ],
        ),
        Container(
          height: 1,
          color: Colors.black,
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TOTAL:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              total.toString(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Container(
          height: 1,
          color: Colors.black,
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        const SizedBox(height: 8),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Notes & Terms:',
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 4),
        Text(notes, style: const TextStyle(fontSize: 8)),
        const SizedBox(height: 24),
        Container(
          height: 1,
          color: Colors.black,
          margin: const EdgeInsets.symmetric(vertical: 8),
        ),
        const Text(
          'Thank You!',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const Text(
          'Please Visit Again',
          style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        Container(
          width: 200,
          height: 32,
          color: Colors.black,
          child: const Center(
            child: Text(
              '|||||| || |||| ||| ||| |||||',
              style: TextStyle(fontSize: 8, color: Colors.white),
            ),
          ),
        ),
        const Text('ET-88291-2024', style: TextStyle(fontSize: 8)),
      ],
    );
  }

  Widget _buildStandardPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.add_circle_outline,
                    size: 40,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  businessName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  businessAddress,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 4),
                Text(
                  '$taxLabel IN: $gstin',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$businessEmail | $businessPhone',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'INVOICE',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade100,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'INV-2024-001',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BILL TO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    clientName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    clientAddress,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TERMS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Due on Receipt',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Net 15 Days',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(3),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade900, width: 2),
                ),
              ),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'DESCRIPTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'QTY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'RATE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'AMOUNT',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            ...items.map(
              (item) => TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.desc,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.details,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      item.qty.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      formatCurrency(item.rate),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      formatCurrency(item.qty * item.rate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: 256,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Subtotal',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                      Text(
                        formatCurrency(subtotal),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$taxLabel ($taxRate%)',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                      Text(
                        formatCurrency(gst),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formatCurrency(total),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 80),
        Container(
          padding: const EdgeInsets.only(top: 32),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notes & Terms',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notes,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
