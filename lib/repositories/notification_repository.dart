import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/models/notification_model.dart';

class NotificationRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> sendNotification({
    required String targetUserId,
    required String title,
    required String message,
    String? ticketId,
  }) async {
    try {
      await _client.from(SupabaseConstants.tableNotifications).insert({
        'target_user_id': targetUserId,
        'title': title,
        'message': message,
        'ticket_id': ticketId,
        'is_read': false,
      });
    } catch (e) {
      rethrow;
    }
  }

  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _client
        .from(SupabaseConstants.tableNotifications)
        .stream(primaryKey: ['id'])
        .eq('target_user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => NotificationModel.fromJson(json)).toList());
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      await _client
          .from(SupabaseConstants.tableNotifications)
          .update({'is_read': true})
          .eq('target_user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableNotifications)
          .select('id')
          .eq('target_user_id', userId)
          .eq('is_read', false);
      
      return (response as List).length;
    } catch (e) {
      rethrow;
    }
  }

  /// Get ALL admin user IDs for a company (supports multiple admins)
  Future<List<String>> getAdminUserIds(String companyCode) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableUsers)
          .select('user_id')
          .eq('company_code', companyCode)
          .eq('role', 'admin')
          .eq('is_active', true);
      
      return (response as List).map((u) => u['user_id'] as String).toList();
    } catch (e) {
      return [];
    }
  }
}
