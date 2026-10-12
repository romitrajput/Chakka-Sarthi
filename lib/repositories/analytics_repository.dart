import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';

/// Analytics repository for tracking user activity and feature usage
class AnalyticsRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /// Track a user action/event
  Future<void> trackEvent({
    required String userId,
    required String action,
    String? details,
    String? ticketId,
  }) async {
    try {
      await _client.from(SupabaseConstants.tableAnalytics).insert({
        'user_id': userId,
        'action': action,
        'details': details,
        'ticket_id': ticketId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Silent fail - analytics should not break the app
      debugPrint('Analytics tracking error: $e');
    }
  }

  /// Track feature usage for a specific user
  Future<void> trackFeatureUsage({
    required String userId,
    required String feature,
    required int count,
  }) async {
    try {
      await _client.from(SupabaseConstants.tableAnalytics).insert({
        'user_id': userId,
        'action': 'feature_usage',
        'details': feature,
        'quantity': count,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Analytics tracking error: $e');
    }
  }

  /// Get user activity summary
  Future<Map<String, dynamic>> getUserActivity(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableAnalytics)
          .select('action, details, created_at, COUNT(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      // Group by action manually in Dart
      final Map<String, int> grouped = {};
      for (final row in response) {
        final action = row['action'] as String;
        grouped[action] = (grouped[action] ?? 0) + 1;
      }

      return {'events': grouped};
    } catch (e) {
      return {'events': []};
    }
  }

  /// Get overall app usage stats for a company
  Future<Map<String, dynamic>> getCompanyUsageStats(String companyCode) async {
    try {
      // Get active users in last 7 days
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();

      final activeUsersRes = await _client
          .from(SupabaseConstants.tableAnalytics)
          .select('user_id')
          .gte('created_at', sevenDaysAgo)
          .eq('action', 'login')
          .order('created_at', ascending: false);

      // Get feature usage counts
      final featureUsageRes = await _client
          .from(SupabaseConstants.tableAnalytics)
          .select('action, COUNT(*)')
          .eq('action', 'feature_usage')
          .order('COUNT(*)', ascending: false);

      return {
        'activeUsers': (activeUsersRes as List).map((u) => u['user_id']).toSet().length,
        'featureUsage': featureUsageRes,
        'period': 'Last 7 days',
      };
    } catch (e) {
      return {'activeUsers': 0, 'featureUsage': [], 'period': 'Last 7 days'};
    }
  }
}
