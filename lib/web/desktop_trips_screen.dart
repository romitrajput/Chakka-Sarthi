import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/utils/pdf_generator.dart';
import 'package:sanjay_roadlines_fleet/models/loading_status_model.dart';
import 'package:sanjay_roadlines_fleet/models/unloading_status_model.dart';
import 'package:sanjay_roadlines_fleet/providers/business_provider.dart';
import 'package:sanjay_roadlines_fleet/providers/driver_names_provider.dart';
import 'package:sanjay_roadlines_fleet/repositories/loading_unloading_repository.dart';
import 'package:sanjay_roadlines_fleet/repositories/report_repository.dart';
import 'package:sanjay_roadlines_fleet/web/desktop_shell.dart';
import 'package:sanjay_roadlines_fleet/web/trips_data.dart';

final _date = DateFormat('dd MMM yyyy');

String statusLabel(String s) => switch (s) {
      'assigned' => 'Assigned',
      'in_transit' => 'In transit',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      _ => s,
    };

/// Coloured status pill used in the website tables.
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'assigned' => (const Color(0xFFFFF2C2), const Color(0xFF7A5B00)),
      'in_transit' => (const Color(0xFFE1E9FC), const Color(0xFF2C5BD6)),
      'completed' => (const Color(0xFFDDF2E7), AppColors.successGreen),
      _ => (const Color(0xFFECECE6), AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(statusLabel(status), style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Website: every trip in one sortable, searchable table.
class DesktopTripsScreen extends ConsumerStatefulWidget {
  const DesktopTripsScreen({super.key});

  @override
  ConsumerState<DesktopTripsScreen> createState() => _DesktopTripsScreenState();
}

class _DesktopTripsScreenState extends ConsumerState<DesktopTripsScreen> {
  String _search = '';
  String _status = 'all';
  String _vehicle = 'all';
  DateTimeRange? _range;
  int _sortColumn = 4;
  bool _ascending = false;

  List<TripRow> _apply(List<TripRow> rows, Map<String, String> names) {
    final q = _search.trim().toLowerCase();
    final out = rows.where((r) {
      final t = r.ticket;
      if (_status != 'all' && t.status != _status) return false;
      if (_vehicle != 'all' && r.vehicleNumber != _vehicle) return false;
      if (_range != null) {
        final d = DateTime(t.assignedAt.year, t.assignedAt.month, t.assignedAt.day);
        if (d.isBefore(_range!.start) || d.isAfter(_range!.end)) return false;
      }
      if (q.isEmpty) return true;
      final driver = names[t.driverUserId] ?? t.driverUserId;
      return t.ticketId.toLowerCase().contains(q) ||
          r.vehicleNumber.toLowerCase().contains(q) ||
          driver.toLowerCase().contains(q) ||
          r.route.toLowerCase().contains(q);
    }).toList();

    int cmp(TripRow a, TripRow b) => switch (_sortColumn) {
          0 => a.ticket.ticketId.compareTo(b.ticket.ticketId),
          1 => a.vehicleNumber.compareTo(b.vehicleNumber),
          2 => (names[a.ticket.driverUserId] ?? '').compareTo(names[b.ticket.driverUserId] ?? ''),
          3 => a.route.compareTo(b.route),
          5 => a.ticket.status.compareTo(b.ticket.status),
          _ => a.ticket.assignedAt.compareTo(b.ticket.assignedAt),
        };
    out.sort((a, b) => _ascending ? cmp(a, b) : cmp(b, a));
    return out;
  }

  void _sort(int column, bool ascending) => setState(() {
        _sortColumn = column;
        _ascending = ascending;
      });

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(allTripsProvider);
    final names = ref.watch(driverNamesProvider).value ?? const <String, String>{};

    return DesktopPage(
      title: 'Trips',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(allTripsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: trips.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load trips: $e')),
        data: (rows) {
          final vehicles = {for (final r in rows) r.vehicleNumber}.toList()..sort();
          final shown = _apply(rows, names);
          return ListView(
            padding: const EdgeInsets.all(28),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 360,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search trip ID, vehicle, driver, place…',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  _dropdown<String>(
                    'Status',
                    _status,
                    const {
                      'all': 'All',
                      'assigned': 'Assigned',
                      'in_transit': 'In transit',
                      'completed': 'Completed',
                    },
                    (v) => setState(() => _status = v),
                  ),
                  _dropdown<String>(
                    'Vehicle',
                    _vehicle,
                    {'all': 'All', for (final v in vehicles) v: v},
                    (v) => setState(() => _vehicle = v),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: Text(_range == null
                        ? 'All dates'
                        : '${_date.format(_range!.start)} – ${_date.format(_range!.end)}'),
                  ),
                  if (_range != null)
                    TextButton(onPressed: () => setState(() => _range = null), child: const Text('Clear dates')),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/admin/create-ticket'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandYellow,
                      foregroundColor: AppColors.ink,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Trip'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TripsTable(
                      rows: shown,
                      names: names,
                      sortColumn: _sortColumn,
                      ascending: _ascending,
                      onSort: _sort,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Showing ${shown.length} of ${rows.length} trips · click a column title to sort',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dropdown<T>(String label, T value, Map<T, String> options, ValueChanged<T> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDADAD2)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: [
            for (final e in options.entries)
              DropdownMenuItem<T>(value: e.key, child: Text('$label: ${e.value}')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// The trips table (also used on the website dashboard).
class TripsTable extends StatelessWidget {
  const TripsTable({
    super.key,
    required this.rows,
    required this.names,
    this.sortColumn,
    this.ascending = false,
    this.onSort,
  });
  final List<TripRow> rows;
  final Map<String, String> names;
  final int? sortColumn;
  final bool ascending;
  final void Function(int column, bool ascending)? onSort;

  @override
  Widget build(BuildContext context) {
    DataColumn col(String label) => DataColumn(
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          onSort: onSort,
        );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            sortColumnIndex: sortColumn,
            sortAscending: ascending,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFFAFAF7)),
            showCheckboxColumn: false,
            columns: [
              col('Trip ID'),
              col('Vehicle'),
              col('Driver'),
              col('Route'),
              col('Assigned'),
              col('Status'),
              const DataColumn(label: Text('')),
            ],
            rows: [
              for (final r in rows)
                DataRow(
                  onSelectChanged: (_) => showTripDetails(context, r),
                  cells: [
                    DataCell(Text(r.ticket.ticketId, style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(r.vehicleNumber)),
                    DataCell(Text(names[r.ticket.driverUserId] ?? r.ticket.driverUserId)),
                    DataCell(Text(r.route)),
                    DataCell(Text(_date.format(r.ticket.assignedAt.toLocal()))),
                    DataCell(StatusPill(r.ticket.status)),
                    const DataCell(Text('Open ›', style: TextStyle(color: AppColors.textSecondary))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trip details pop-up, with the trip report for completed trips.
Future<void> showTripDetails(BuildContext context, TripRow row) {
  return showDialog(
    context: context,
    builder: (_) => _TripDetailsDialog(row: row),
  );
}

class _TripDetailsDialog extends ConsumerStatefulWidget {
  const _TripDetailsDialog({required this.row});
  final TripRow row;

  @override
  ConsumerState<_TripDetailsDialog> createState() => _TripDetailsDialogState();
}

class _TripDetailsDialogState extends ConsumerState<_TripDetailsDialog> {
  final _repo = LoadingUnloadingRepository();
  late final Future<(LoadingStatusModel?, UnloadingStatusModel?)> _forms = () async {
    final t = widget.row.ticket.ticketId;
    final loading = await _repo.getLoadingStatus(t);
    final unloading = await _repo.getUnloadingStatus(t);
    return (loading, unloading);
  }();
  bool _printing = false;

  Future<void> _report(LoadingStatusModel loading, UnloadingStatusModel unloading) async {
    setState(() => _printing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final t = widget.row.ticket;
      final bytes = await PdfGenerator.generateTripPdf(
        ticket: t,
        loading: loading,
        unloading: unloading,
        companyName: await currentBusinessName(ref),
        unloadedBy: driverNameOf(ref, t.driverUserId),
        consignerName: await ReportRepository().consignerName(t.ticketId),
        driverChanges: await ReportRepository().driverChangeLines(t.ticketId),
      );
      await Printing.layoutPdf(onLayout: (PdfPageFormat _) async => bytes, name: 'Trip_Report_${t.ticketId}');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not make the report: $e'), backgroundColor: AppColors.errorRed));
    }
    if (mounted) setState(() => _printing = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final t = r.ticket;
    ref.watch(driverNamesProvider);
    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 170, child: Text(k, style: const TextStyle(color: AppColors.textSecondary))),
              Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        );
    String kg(double v) => '${v.toStringAsFixed(2)} kg';

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(t.ticketId)),
          StatusPill(t.status),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<(LoadingStatusModel?, UnloadingStatusModel?)>(
          future: _forms,
          builder: (context, snap) {
            final loading = snap.data?.$1;
            final unloading = snap.data?.$2;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  line('Vehicle', r.vehicleNumber),
                  line('Driver', driverNameOf(ref, t.driverUserId)),
                  line('Assigned by', t.createdBy.isEmpty ? '—' : t.createdBy),
                  line('Assigned on', _date.format(t.assignedAt.toLocal())),
                  if (t.completedAt != null) line('Completed on', _date.format(t.completedAt!.toLocal())),
                  if (snap.connectionState != ConnectionState.done)
                    const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
                  if (loading != null) ...[
                    const Divider(height: 24),
                    const Text('Loading', style: TextStyle(fontWeight: FontWeight.w700)),
                    line('LR number', loading.lrNumber),
                    line('Route', '${loading.journeyFrom} → ${loading.journeyTo}'),
                    line('Consigner', loading.consigneeName),
                    line('Product', loading.product),
                    line('Loading weight', kg(loading.loadingWeightKgs)),
                  ],
                  if (unloading != null) ...[
                    const Divider(height: 24),
                    const Text('Unloading', style: TextStyle(fontWeight: FontWeight.w700)),
                    line('Unloading weight', kg(unloading.unloadingWeightKgs)),
                    line('Shortage', kg(unloading.shortageKgs)),
                    line('Unloading date', _date.format(unloading.unloadingDate.toLocal())),
                    if (t.detentionDays != null) line('Detention', '${t.detentionDays} days'),
                  ],
                  if (snap.connectionState == ConnectionState.done && loading == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('Loading details not filled yet.', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        FutureBuilder<(LoadingStatusModel?, UnloadingStatusModel?)>(
          future: _forms,
          builder: (context, snap) {
            final loading = snap.data?.$1;
            final unloading = snap.data?.$2;
            if (t.status != 'completed' || loading == null || unloading == null) {
              return const SizedBox.shrink();
            }
            return OutlinedButton.icon(
              onPressed: _printing ? null : () => _report(loading, unloading),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_printing ? 'Preparing…' : 'Trip report (PDF)'),
            );
          },
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}
