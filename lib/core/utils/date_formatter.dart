import 'package:intl/intl.dart';

class DateFormatter {
  static String formatIST(DateTime dateTime) {
    // Convert to UTC if not already, then add 5:30 for IST
    final istDate = dateTime.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd MMM yyyy, hh:mm a').format(istDate);
  }

  static String formatDateOnly(DateTime dateTime) {
    final istDate = dateTime.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd MMM yyyy').format(istDate);
  }

  static String formatTimeOnly(DateTime dateTime) {
    final istDate = dateTime.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('hh:mm a').format(istDate);
  }
}
