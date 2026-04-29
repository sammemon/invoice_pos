import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class Helpers {
  static String formatCurrency(double amount) =>
      '${AppConstants.currency}${NumberFormat('#,##0.00').format(amount)}';

  static String formatAmount(num amount) =>
      NumberFormat('#,##0').format(amount);

  static String formatDate(DateTime date) =>
      DateFormat('dd MMM yyyy').format(date);

  static String formatDateTime(DateTime date) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(date);

  static String formatDateOnly(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  static String generateId() =>
      DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase() +
      (1000 + (DateTime.now().microsecond % 9000)).toString();

  static String generateInvoiceNumber() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return '${AppConstants.invoicePrefix}-$ts';
  }

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  static DateTime startOfMonth([DateTime? date]) {
    final d = date ?? DateTime.now();
    return DateTime(d.year, d.month, 1);
  }

  static DateTime endOfMonth([DateTime? date]) {
    final d = date ?? DateTime.now();
    return DateTime(d.year, d.month + 1, 0, 23, 59, 59);
  }
}
