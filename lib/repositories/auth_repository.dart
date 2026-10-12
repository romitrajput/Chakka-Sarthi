import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sanjay_roadlines_fleet/core/constants/supabase_constants.dart';
import 'package:sanjay_roadlines_fleet/models/user_model.dart';


class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _userKey = 'logged_in_user_id';
  static const String _rememberKey = 'remember_me';

  String _hash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<void> saveSession(String userId, {bool remember = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, userId);
    await prefs.setBool(_rememberKey, remember);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_rememberKey);
    await Supabase.instance.client.auth.signOut();
  }

  Future<String?> getSavedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool(_rememberKey) ?? false;
    if (!remember) return null;
    return prefs.getString(_userKey);
  }

  Future<UserModel?> loginWithPassword(
      String userId, String mobile, {bool remember = false}) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableUsers)
          .select('id, user_id, full_name, mobile, role, company_code, mpin_hash, is_first_login, is_active, sequential_num, created_at')
          .eq('user_id', userId.trim())
          .eq('mobile', mobile.trim())
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        throw Exception('Invalid User ID or mobile number');
      }

      final user = UserModel.fromJson(response);
      // Allow mobile login only on first login
      if (!user.isFirstLogin) {
        throw Exception('MPIN already set. Please login using your MPIN');
      }

      await saveSession(user.userId, remember: remember);

// Create Supabase Auth session
      if (Supabase.instance.client.auth.currentUser == null) {
        await Supabase.instance.client.auth.signInAnonymously();
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> loginWithMpin(
      String userId, String mpin, {bool remember = false}) async {
    try {
      final hashedMpin = _hash(mpin.trim());
      final response = await _client
          .from(SupabaseConstants.tableUsers)
          .select('id, user_id, full_name, mobile, role, company_code, mpin_hash, is_first_login, is_active, sequential_num, created_at')
          .eq('user_id', userId.trim())
          .eq('mpin_hash', hashedMpin)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        throw Exception('Invalid User ID or MPIN');
      }

      final user = UserModel.fromJson(response);
      if (user.isFirstLogin) {
        throw Exception('Please login with mobile number first to set your MPIN');
      }

      await saveSession(user.userId, remember: remember);

// Create Supabase Auth session
      if (Supabase.instance.client.auth.currentUser == null) {
        await Supabase.instance.client.auth.signInAnonymously();
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setMpin(String userId, String mpin) async {
    try {
      final hashedMpin = _hash(mpin.trim());
      await _client
          .from(SupabaseConstants.tableUsers)
          .update({'mpin_hash': hashedMpin, 'is_first_login': false})
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetMpin(String userId) async {
    try {
      await _client
          .from(SupabaseConstants.tableUsers)
          .update({'is_first_login': true, 'mpin_hash': null})
          .eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getUserDetails(String userId) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableUsers)
          .select('id, user_id, full_name, mobile, role, company_code, mpin_hash, is_first_login, is_active, sequential_num, created_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Verify super admin reset code for a company
  Future<bool> verifyResetCode(String companyCode, String resetCode) async {
    try {
      final response = await _client
          .from(SupabaseConstants.tableCompanies)
          .select('reset_code')
          .eq('company_code', companyCode)
          .maybeSingle();

      if (response == null) return false;
      final storedCode = response['reset_code'] as String?;
      if (storedCode == null || storedCode.isEmpty) return false;
      return storedCode == resetCode;
    } catch (e) {
      rethrow;
    }
  }

  /// Reset all company data (vehicles, tickets, notifications, etc.)
  /// Keeps the company and admin/driver user accounts intact
  Future<void> resetCompanyData(String companyCode) async {
    try {
      // Fetch ticket IDs before deleting (for loading/unloading cleanup)
      final tickets = await _client
          .from(SupabaseConstants.tableTickets)
          .select('id')
          .eq('company_code', companyCode);

      final ticketIds = tickets.map((t) => t['id'] as String).toList();

      // Delete loading/unloading records for these tickets
      for (final tid in ticketIds) {
        await _client
            .from(SupabaseConstants.tableLoadingStatus)
            .delete()
            .eq('ticket_id', tid);
        await _client
            .from(SupabaseConstants.tableUnloadingStatus)
            .delete()
            .eq('ticket_id', tid);
      }

      // Delete all tickets for this company
      await _client
          .from(SupabaseConstants.tableTickets)
          .delete()
          .eq('company_code', companyCode);

      // Delete all vehicles for this company
      await _client
          .from(SupabaseConstants.tableVehicles)
          .delete()
          .eq('company_code', companyCode);

      // Delete trip reassignments linked to these tickets
      for (final tid in ticketIds) {
        await _client
            .from(SupabaseConstants.tableTripReassignments)
            .delete()
            .eq('ticket_id', tid);
      }

      // Delete all notifications for this company's users
      final users = await _client
          .from(SupabaseConstants.tableUsers)
          .select('user_id')
          .eq('company_code', companyCode);

      for (final user in users) {
        await _client
            .from(SupabaseConstants.tableNotifications)
            .delete()
            .eq('target_user_id', user['user_id']);
      }

      // Delete trip reassignments for this company
      await _client
          .from(SupabaseConstants.tableTripReassignments)
          .delete()
          .eq('company_code', companyCode);
    } catch (e) {
      rethrow;
    }
  }
}
