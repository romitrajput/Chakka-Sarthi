import 'package:intl/intl.dart';

class TripReassignmentModel {
  final String id;
  final String ticketId;
  final String oldDriverUserId;
  final String newDriverUserId;
  final String reassignedBy;
  final DateTime reassignedAt;
  final String? reason;
  final String reassignedAtStage; // assigned | loading | unloading | completed

  TripReassignmentModel({
    required this.id,
    required this.ticketId,
    required this.oldDriverUserId,
    required this.newDriverUserId,
    required this.reassignedBy,
    required this.reassignedAt,
    this.reason,
    this.reassignedAtStage = 'assigned',
  });

  factory TripReassignmentModel.fromJson(Map<String, dynamic> json) {
    return TripReassignmentModel(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String,
      oldDriverUserId: json['old_driver_user_id'] as String,
      newDriverUserId: json['new_driver_user_id'] as String,
      reassignedBy: json['reassigned_by'] as String,
      reassignedAt: DateTime.parse(json['reassigned_at'] as String),
      reason: json['reason'] as String?,
      reassignedAtStage: json['reassigned_at_stage'] as String? ?? 'assigned',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'old_driver_user_id': oldDriverUserId,
      'new_driver_user_id': newDriverUserId,
      'reassigned_by': reassignedBy,
      'reassigned_at': reassignedAt.toIso8601String(),
      'reason': reason,
      'reassigned_at_stage': reassignedAtStage,
    };
  }

  String get formattedReassignedAt {
    final istDate = reassignedAt.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd MMM yyyy, hh:mm a').format(istDate);
  }
}
