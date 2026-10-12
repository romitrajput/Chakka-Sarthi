import 'package:intl/intl.dart';

class NotificationModel {
  final String id;
  final String targetUserId;
  final String title;
  final String message;
  final bool isRead;
  final String? ticketId;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.targetUserId,
    required this.title,
    required this.message,
    this.isRead = false,
    this.ticketId,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      targetUserId: json['target_user_id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool? ?? false,
      ticketId: json['ticket_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'target_user_id': targetUserId,
      'title': title,
      'message': message,
      'is_read': isRead,
      'ticket_id': ticketId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get formattedCreatedAt {
    final istDate = createdAt.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd MMM yyyy, hh:mm a').format(istDate);
  }
}
