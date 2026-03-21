import '../templates/fresh_mart_grocery_template.dart';
import '../templates/electronics_detailed_template.dart';
import '../templates/retail_basic_template.dart';
import '../templates/design_systems_india_template.dart';
import 'invoice_template.dart';

class TemplateRegistry {
  // Register exactly the templates you want the user to see!
  static final List<InvoiceTemplate> availableTemplates = <InvoiceTemplate>[
    DesignSystemsIndiaTemplate(),
    RetailBasicTemplate(),
    FreshMartGroceryTemplate(),
    ElectronicsDetailedTemplate(),
    // Add A4IndiaDesignSystemTemplate(), etc.
  ];

  static InvoiceTemplate getTemplateById(String id) {
    return availableTemplates.firstWhere(
      (t) => t.id == id,
      orElse: () => availableTemplates.first, // Fallback
    );
  }
}
