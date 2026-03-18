import 'package:flutter/material.dart';
import 'models.dart';

// --- Selection Screen ---

class _NavLink extends StatelessWidget {
  final String text;
  final bool isActive;

  const _NavLink({required this.text, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.blue : Colors.grey.shade600,
          ),
        ),
        if (isActive)
          Container(
            margin: const EdgeInsets.only(top: 6),
            height: 2,
            width: text.length * 8.0,
            color: Colors.blue,
          ),
      ],
    );
  }
}

class SelectionScreen extends StatefulWidget {
  final Function(String) onEdit;

  const SelectionScreen({super.key, required this.onEdit});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  String activeFormat = 'Thermal Receipt';
  String activeIndustry = 'All Industries';
  String? previewImage;

  final List<String> formats = [
    'Thermal Receipt',
    'A5 Half-Page',
    'A4 Full-Page',
  ];
  final List<String> industries = [
    'All Industries',
    'Retail',
    'Grocery',
    'Garment',
    'Electronics',
    'Restaurant',
  ];

  final List<Template> templates = [
    Template(
      id: '1',
      name: 'Retail Basic',
      industry: 'RETAIL',
      format: 'A4',
      style: 'COMPACT',
      image:
          'https://images.unsplash.com/photo-1586281380349-632531db7ed4?auto=format&fit=crop&q=80&w=400',
      metadata: 'Standard Retail Format',
      tag: 'POPULAR',
    ),
    Template(
      id: '2',
      name: 'Grocery GST Detailed',
      industry: 'GROCERY',
      format: 'THERMAL',
      style: 'DETAILED',
      image: 'screen.png',
      metadata: 'HSN & Weight Ready',
      tag: 'GST COMPLIANT',
      styleColor: Colors.green.shade600,
    ),
    Template(
      id: '3',
      name: 'Garment Elegant',
      industry: 'GARMENT',
      format: 'A5',
      style: 'STYLE FOCUS',
      image:
          'https://images.unsplash.com/photo-1626266061368-46a8f578ddd6?auto=format&fit=crop&q=80&w=400',
      metadata: 'Boutique Look',
      tag: 'FEATURED',
      styleColor: Colors.purple.shade600,
    ),
    Template(
      id: '4',
      name: 'Electronics Warranty',
      industry: 'ELECTRONICS',
      format: 'A4',
      style: 'WARRANTY FOCUS',
      image:
          'https://images.unsplash.com/photo-1512428559083-a40ce75b8956?auto=format&fit=crop&q=80&w=400',
      metadata: 'Serial No. Tracking',
      tag: 'SAFE CHOICE',
      styleColor: Colors.orange.shade600,
    ),
    Template(
      id: '5',
      name: 'Restaurant Table Service',
      industry: 'RESTAURANT',
      format: 'A4',
      style: 'DETAILED',
      image:
          'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?auto=format&fit=crop&q=80&w=400',
      metadata: 'Tips & Split Ready',
      tag: 'PREMIUM',
      styleColor: Colors.indigo.shade600,
    ),
    Template(
      id: '6',
      name: 'Retail Discount Focus',
      industry: 'RETAIL',
      format: 'THERMAL',
      style: 'DISCOUNT FOCUS',
      image: 'screen.png',
      metadata: 'Save Taglines Ready',
      tag: 'HIGHROI',
      styleColor: Colors.red.shade600,
    ),
    Template(
      id: '7',
      name: 'Garment Discount Style',
      industry: 'GARMENT',
      format: 'A5',
      style: 'PROMO STYLE',
      image:
          'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&q=80&w=400',
      metadata: 'Season Sale Ready',
      tag: 'TRENDING',
      styleColor: Colors.pink.shade500,
    ),
    Template(
      id: '8',
      name: 'Electronics Detailed Invoice',
      industry: 'ELECTRONICS',
      format: 'THERMAL',
      style: 'DETAILED',
      image: 'screen.png',
      metadata: 'Specs & IMEI Columns',
      tag: 'PRO GRADE',
      styleColor: Colors.grey.shade700,
    ),
    Template(
      id: '9',
      name: 'Restaurant Quick Bill',
      industry: 'RESTAURANT',
      format: 'THERMAL',
      style: 'QUICK BILLING',
      image: 'screen.png',
      metadata: 'Optimized for Counter',
      tag: 'FAST',
      styleColor: Colors.amber.shade600,
    ),
    Template(
      id: '10',
      name: 'Fresh Mart Grocery',
      industry: 'GROCERY',
      format: 'THERMAL',
      style: 'COMPACT',
      image:
          'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=400',
      metadata: '58mm/80mm optimized',
      tag: 'GROCERY SPECIAL',
      styleColor: Colors.green.shade600,
    ),
    Template(
      id: '11',
      name: 'Cozy Corner Cafe',
      industry: 'RESTAURANT',
      format: 'THERMAL',
      style: 'CAFE STYLE',
      image:
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&q=80&w=400',
      metadata: 'Table & Dine-in Ready',
      tag: 'CAFE FAVORITE',
      styleColor: Colors.orange.shade500,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopNavBar(),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPageHeader(),
                        const SizedBox(height: 24),
                        _buildFormatTabs(),
                        const SizedBox(height: 24),
                        _buildIndustryFilters(),
                        const SizedBox(height: 32),
                        _buildTemplateGrid(),
                        const SizedBox(height: 48),
                        _buildPagination(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (previewImage != null) _buildImagePreview(),
        ],
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      height: 64,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.credit_card,
                  size: 20,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'InvoiceGenius ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    WidgetSpan(
                      child: Transform.translate(
                        offset: const Offset(2, -8),
                        child: Text(
                          'POS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 32),
                _NavLink(text: 'Templates', isActive: true),
                const SizedBox(width: 24),
                _NavLink(text: 'Bills', isActive: false),
                const SizedBox(width: 24),
                _NavLink(text: 'Inventory', isActive: false),
                const SizedBox(width: 24),
                _NavLink(text: 'Analytics', isActive: false),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Container(
            width: 256,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const TextField(
              decoration: InputDecoration(
                hintText: 'Search POS layouts...',
                hintStyle: TextStyle(fontSize: 14),
                prefixIcon: Icon(Icons.search, size: 16),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(
                Icons.notifications_none,
                size: 20,
                color: Colors.grey.shade600,
              ),
              onPressed: () {},
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue.shade100, width: 2),
              borderRadius: BorderRadius.circular(20),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=facearea&facepad=2&w=100&h=100&q=80',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select POS Template',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade900,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose a bill format optimized for your industry',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade500),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Custom POS Layout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: Colors.blue.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatTabs() {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: formats.map((format) {
          final isActive = format == activeFormat;
          return GestureDetector(
            onTap: () => setState(() => activeFormat = format),
            child: Container(
              padding: const EdgeInsets.only(bottom: 12, left: 4, right: 4),
              margin: const EdgeInsets.only(right: 32),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? Colors.blue : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                format,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.grey.shade900 : Colors.grey.shade500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIndustryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: industries.map((industry) {
          final isActive = industry == activeIndustry;
          return GestureDetector(
            onTap: () => setState(() => activeIndustry = industry),
            child: Container(
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isActive ? Colors.blue : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Center(
                child: Text(
                  industry,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTemplateGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 32,
        mainAxisSpacing: 32,
        childAspectRatio: 0.75,
      ),
      itemCount: templates.length + 1,
      itemBuilder: (context, index) {
        if (index == templates.length) {
          return _buildAddTemplatePlaceholder();
        }
        return _buildTemplateCard(templates[index]);
      },
    );
  }

  Widget _buildTemplateCard(Template template) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: template.image == 'screen.png'
                      ? Container(color: Colors.grey.shade100)
                      : Image.network(
                          template.image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: Colors.grey.shade100);
                          },
                        ),
                ),
              ),
              // Hover overlay - simplified for Flutter web
              // In Flutter, we'll use a different approach for hover
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade900.withOpacity(0.6),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              setState(() => previewImage = template.image),
                          child: Container(
                            width: 200,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Preview',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => widget.onEdit(template.id),
                          child: Container(
                            width: 200,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text(
                                'Select for POS',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${template.industry} | ${template.format}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            template.styleColor ??
                            Colors.grey.shade900.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        template.style,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              template.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  template.metadata,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  template.tag?.toUpperCase() ?? '',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAddTemplatePlaceholder() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_circle_outline,
                        size: 40,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Blank Industry Layout',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start scratch with POS metadata',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing 1-10 of 42 industry-specialized templates',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade500,
          ),
        ),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  '1',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _buildPageButton('2'),
            const SizedBox(width: 8),
            _buildPageButton('3'),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.grey.shade400,
                ),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPageButton(String text) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: () => setState(() => previewImage = null),
      child: Container(
        color: Colors.grey.shade900.withOpacity(0.8),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxHeight: 600),
                        child: Image.network(
                          previewImage!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 400,
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: Text('Image not available'),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: () => setState(() => previewImage = null),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade100),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Template Preview',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'High-resolution industry specialized layout',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => setState(() => previewImage = null),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Close Preview'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
