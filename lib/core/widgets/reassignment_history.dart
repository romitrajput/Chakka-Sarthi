import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

/// One step in a trip's driver history.
class _DriverStep {
  final String driverId;
  final String driverName;
  final DateTime? at;
  final String? stage;
  final String? reason;
  final String? by;
  const _DriverStep(this.driverId, this.driverName, {this.at, this.stage, this.reason, this.by});
}

String _stageLabel(String? stage) {
  switch (stage) {
    case 'assigned':
      return 'before loading';
    case 'loading':
      return 'in transit';
    case 'unloading':
      return 'at unloading';
    case 'completed':
      return 'after completion';
    default:
      return stage ?? '';
  }
}

Future<List<_DriverStep>> _loadHistory(String ticketId) async {
  final client = Supabase.instance.client;
  final logs = await client
      .from(SupabaseConstants.tableTripReassignments)
      .select('old_driver_user_id, new_driver_user_id, reassigned_by, reassigned_at, reason, reassigned_at_stage')
      .eq('ticket_id', ticketId)
      .order('reassigned_at', ascending: true);
  final rows = (logs as List).cast<Map<String, dynamic>>();
  if (rows.isEmpty) return [];

  // Look up driver names
  final ids = <String>{
    for (final r in rows) ...[r['old_driver_user_id'] as String, r['new_driver_user_id'] as String],
  };
  final users = await client
      .from(SupabaseConstants.tableUsers)
      .select('user_id, full_name')
      .inFilter('user_id', ids.toList());
  final names = {
    for (final u in (users as List).cast<Map<String, dynamic>>()) u['user_id'] as String: u['full_name'] as String,
  };
  String nameOf(String id) => names[id] ?? id;

  final steps = <_DriverStep>[
    _DriverStep(rows.first['old_driver_user_id'] as String, nameOf(rows.first['old_driver_user_id'] as String)),
  ];
  for (final r in rows) {
    final newId = r['new_driver_user_id'] as String;
    steps.add(_DriverStep(
      newId,
      nameOf(newId),
      at: DateTime.tryParse(r['reassigned_at'] as String? ?? ''),
      stage: r['reassigned_at_stage'] as String?,
      reason: r['reason'] as String?,
      by: r['reassigned_by'] as String?,
    ));
  }
  return steps;
}

/// Timeline of every driver a trip has had: original driver first, current driver last.
class ReassignmentHistory extends StatelessWidget {
  const ReassignmentHistory({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_DriverStep>>(
      future: _loadHistory(ticketId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text('Could not load history: ${snapshot.error}',
              style: const TextStyle(color: AppColors.errorRed, fontSize: 12));
        }
        final steps = snapshot.data ?? [];
        if (steps.isEmpty) {
          return const Text('This trip has not been re-assigned.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13));
        }
        return Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              _StepTile(step: steps[i], isFirst: i == 0, isCurrent: i == steps.length - 1),
          ],
        );
      },
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.isFirst, required this.isCurrent});

  final _DriverStep step;
  final bool isFirst;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final dotColor = isCurrent ? AppColors.successGreen : AppColors.textSecondary;
    final when = step.at == null
        ? null
        : DateFormat('dd MMM yyyy, hh:mm a').format(step.at!.toUtc().add(const Duration(hours: 5, minutes: 30)));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(width: 2, height: 6, color: isFirst ? Colors.transparent : AppColors.divider),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                Expanded(
                  child: Container(width: 2, color: isCurrent ? Colors.transparent : AppColors.divider),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(step.driverName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      const SizedBox(width: 6),
                      if (isFirst)
                        const _Tag('Original', AppColors.textSecondary)
                      else if (isCurrent)
                        const _Tag('Current', AppColors.successGreen),
                    ],
                  ),
                  Text(step.driverId, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  if (!isFirst) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Took over ${_stageLabel(step.stage)}${when != null ? ' · $when' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (step.reason != null && step.reason!.trim().isNotEmpty)
                      Text('Reason: ${step.reason}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    if (step.by != null && step.by!.isNotEmpty)
                      Text('By: ${step.by}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// Opens the driver history for a trip in a bottom sheet.
void showReassignmentHistory(BuildContext context, String ticketId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (ctx, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Driver history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Trip $ticketId', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ReassignmentHistory(ticketId: ticketId),
          ],
        ),
      ),
    ),
  );
}
