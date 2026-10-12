import 'package:intl/intl.dart';

class UserModel {
  final String id;
  final String userId;
  final String fullName;
  final String mobile;
  final String role;
  final String companyCode;
  final String? mpinHash;
  final bool isFirstLogin;
  final bool isActive;
  final int sequentialNum;
  final DateTime createdAt;
  final String? drivingLicenseUrl;
  final String? aadhaarCardUrl;

  const UserModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.mobile,
    required this.role,
    required this.companyCode,
    this.mpinHash,
    this.isFirstLogin = true,
    this.isActive = true,
    required this.sequentialNum,
    required this.createdAt,
    this.drivingLicenseUrl,
    this.aadhaarCardUrl,
  });

  UserModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? mobile,
    String? role,
    String? companyCode,
    String? mpinHash,
    bool? isFirstLogin,
    bool? isActive,
    int? sequentialNum,
    DateTime? createdAt,
    String? drivingLicenseUrl,
    String? aadhaarCardUrl,
  }) {
    return UserModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      companyCode: companyCode ?? this.companyCode,
      mpinHash: mpinHash ?? this.mpinHash,
      isFirstLogin: isFirstLogin ?? this.isFirstLogin,
      isActive: isActive ?? this.isActive,
      sequentialNum: sequentialNum ?? this.sequentialNum,
      createdAt: createdAt ?? this.createdAt,
      drivingLicenseUrl: drivingLicenseUrl ?? this.drivingLicenseUrl,
      aadhaarCardUrl: aadhaarCardUrl ?? this.aadhaarCardUrl,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      mobile: json['mobile'] as String,
      role: json['role'] as String,
      companyCode: json['company_code'] as String,
      mpinHash: json['mpin_hash'] as String?,
      isFirstLogin: json['is_first_login'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      sequentialNum: json['sequential_num'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      drivingLicenseUrl: json['driving_license_url'] as String?,
      aadhaarCardUrl: json['aadhaar_card_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'mobile': mobile,
      'role': role,
      'company_code': companyCode,
      'mpin_hash': mpinHash,
      'is_first_login': isFirstLogin,
      'is_active': isActive,
      'sequential_num': sequentialNum,
      'created_at': createdAt.toIso8601String(),
      'driving_license_url': drivingLicenseUrl,
      'aadhaar_card_url': aadhaarCardUrl,
    };
  }

  String get formattedCreatedAt {
    final istDate = createdAt.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd MMM yyyy, hh:mm a').format(istDate);
  }
}
