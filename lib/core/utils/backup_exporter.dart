import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:sanjay_roadlines_fleet/core/utils/file_share.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

/// Full backup of the company's data as one Excel file (one sheet per table),
/// opened in the share sheet so the admin can save it to Drive, email it, etc.
/// MPINs and other secrets are never included. Photos stay online; their links are included.
class BackupExporter {
  static final _client = Supabase.instance.client;

  /// Each sheet: name → (table, columns to read). The database only returns
  /// rows of the signed-in admin's own company.
  static const _sheets = <String, (String, String)>{
    'Company': (SupabaseConstants.tableCompanies, 'company_code, company_name, short_name, state_code, created_at'),
    'People': (SupabaseConstants.tableUsers,
        'user_id, full_name, mobile, role, is_active, is_first_login, license_expiry, driving_license_url, aadhaar_card_url, created_at'),
    'Vehicles': (SupabaseConstants.tableVehicles,
        'vehicle_number, status, maintenance_reason, maintenance_from, maintenance_expected_return, created_at'),
    'Trips': (SupabaseConstants.tableTickets,
        'ticket_id, vehicle_id, driver_user_id, status, assigned_at, completed_at, reporting_date, retention_days, reassignment_count, reassigned_from, created_by, challan_urls, pdf_url, created_at'),
    'Loading': (SupabaseConstants.tableLoadingStatus, '*'),
    'Unloading': (SupabaseConstants.tableUnloadingStatus, '*'),
    'Driver changes': (SupabaseConstants.tableTripReassignments, '*'),
    'Notifications': (SupabaseConstants.tableNotifications, '*'),
  };

  static CellValue? _cell(dynamic v) {
    if (v == null) return null;
    if (v is int) return IntCellValue(v);
    if (v is double) return DoubleCellValue(v);
    if (v is bool) return TextCellValue(v ? 'Yes' : 'No');
    if (v is List) return TextCellValue(v.join(', '));
    return TextCellValue(v.toString());
  }

  /// Builds the backup file. Returns the file and a short summary like "8 sheets · 154 rows".
  static Future<(BackupFile, String)> buildFullBackup({required String businessName}) async {
    final excel = Excel.createExcel();
    final bold = CellStyle(bold: true);
    int totalRows = 0;
    bool first = true;

    // Vehicle numbers instead of internal vehicle ids on the Trips sheet
    final vehicleRows = await _client.from(SupabaseConstants.tableVehicles).select('id, vehicle_number');
    final vehicleNo = {
      for (final v in (vehicleRows as List).cast<Map<String, dynamic>>()) v['id'].toString(): v['vehicle_number'],
    };

    for (final entry in _sheets.entries) {
      final (table, cols) = entry.value;
      List<Map<String, dynamic>> rows;
      try {
        rows = ((await _client.from(table).select(cols)) as List).cast<Map<String, dynamic>>();
      } catch (_) {
        rows = []; // a table the admin can't read: leave the sheet empty
      }
      if (entry.key == 'Trips') {
        rows = rows.map((r) => {...r, 'vehicle_id': vehicleNo[r['vehicle_id']?.toString()] ?? r['vehicle_id']}).toList();
      }

      if (first) {
        excel.rename('Sheet1', entry.key);
        first = false;
      }
      final sheet = excel[entry.key];
      final headers = <String>{for (final r in rows) ...r.keys}.toList();
      if (headers.isEmpty) {
        sheet.appendRow([TextCellValue('No data')]);
        continue;
      }
      sheet.appendRow(headers
          .map((h) => TextCellValue(h == 'ticket_id' ? 'trip_id' : (h == 'vehicle_id' && entry.key == 'Trips' ? 'vehicle_number' : h)))
          .toList());
      for (var c = 0; c < headers.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = bold;
        sheet.setColumnWidth(c, 20);
      }
      for (final r in rows) {
        sheet.appendRow(headers.map((h) => _cell(r[h])).toList());
      }
      totalRows += rows.length;
    }

    final bytes = excel.save();
    if (bytes == null) throw Exception('Could not create the backup file');

    final stamp = DateFormat('dd-MMM-yyyy_HHmm').format(DateTime.now());
    final safeName = businessName.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final file = BackupFile(bytes, 'Backup_${safeName}_$stamp.xlsx');
    return (file, '${_sheets.length} sheets · $totalRows rows');
  }

  /// Phone: opens the share sheet (Drive, Gmail, WhatsApp, Files…). Web: downloads the file.
  static Future<void> share(BackupFile file, String businessName) async {
    await FileShare.shareBytes(
      file.bytes,
      fileName: file.name,
      mimeType: FileShare.xlsxMime,
      subject: '$businessName – data backup',
      text: 'Chakka Saarthi data backup of $businessName',
    );
  }
}

class BackupFile {
  final List<int> bytes;
  final String name;
  const BackupFile(this.bytes, this.name);
}
