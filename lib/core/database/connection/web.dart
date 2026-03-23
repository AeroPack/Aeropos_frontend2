import 'package:drift/drift.dart';
// ignore: deprecated_member_use
import 'package:drift/web.dart';

QueryExecutor connect() {
  return WebDatabase('ezo_pos_product_master');
}
