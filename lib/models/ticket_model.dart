import 'package:intl/intl.dart';

class TicketModel {
  final String id;
  final String ticketId;
  final String vehicleId;
  final String driverUserId;
  final String companyCode;
  final String status; // assigned | in_transit | completed | cancelled
  final DateTime assignedAt;
  final DateTime? completedAt;
  final String createdBy;
  final String? createdByUserId; // Admin user ID who created this ticket
  final String? pdfUrl;
  final DateTime createdAt;
  final DateTime? reportingDate;
  final List<String> challanUrls;
  final String? reassignedFrom;
  final int reassignmentCount;
  final int? detentionDays;

  TicketModel({
    required this.id,
    required this.ticketId,
    required this.vehicleId,
    required this.driverUserId,
    required this.companyCode,
    required this.status,
    required this.assignedAt,
    this.completedAt,
    required this.createdBy,
    this.createdByUserId,
    this.pdfUrl,
    required this.createdAt,
    this.reportingDate,
    this.challanUrls = const [],
    this.reassignedFrom,
    this.reassignmentCount = 0,
    this.detentionDays,
  });

  TicketModel copyWith({
    String? id,
    String? ticketId,
    String? vehicleId,
    String? driverUserId,
    String? companyCode,
    String? status,
    DateTime? assignedAt,
    DateTime? completedAt,
    String? createdBy,
    String? pdfUrl,
    DateTime? createdAt,
    DateTime? reportingDate,
    List<String>? challanUrls,
    String? reassignedFrom,
    int? reassignmentCount,
    int? detentionDays,
  }) {
    return    TicketModel(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      vehicleId: vehicleId ?? this.vehicleId,
      driverUserId: driverUserId ?? this.driverUserId,
      companyCode: companyCode ?? this.companyCode,
      status: status ?? this.status,
      assignedAt: assignedAt ?? this.assignedAt,
      completedAt: completedAt ?? this.completedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      createdAt: createdAt ?? this.createdAt,
      reportingDate: reportingDate ?? this.reportingDate,
      challanUrls: challanUrls ?? this.challanUrls,
      reassignedFrom: reassignedFrom ?? this.reassignedFrom,
      reassignmentCount: reassignmentCount ?? this.reassignmentCount,
      detentionDays: detentionDays ?? this.detentionDays,
    );
  }

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String,
      vehicleId: json['vehicle_id'] as String,
      driverUserId: json['driver_user_id'] as String,
      companyCode: json['company_code'] as String,
      status: json['status'] as String,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdBy: json['created_by'] as String,
      createdByUserId: json['created_by_user_id'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      reportingDate: json['reporting_date'] != null
          ? DateTime.parse(json['reporting_date'] as String)
          : null,
      challanUrls: json['challan_urls'] != null
          ? List<String>.from(json['challan_urls'] as List)
          : [],
      reassignedFrom: json['reassigned_from'] as String?,
      reassignmentCount: json['reassignment_count'] as int? ?? 0,
      detentionDays: json['retention_days'] as int?, // Days between unloading and reporting date
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'vehicle_id': vehicleId,
      'driver_user_id': driverUserId,
      'company_code': companyCode,
      'status': status,
      'assigned_at': assignedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_by': createdBy,
      if (createdByUserId != null) 'created_by_user_id': createdByUserId,
      'pdf_url': pdfUrl,
      'created_at': createdAt.toIso8601String(),
      'reporting_date': reportingDate?.toIso8601String(),
      'challan_urls': challanUrls,
      'reassigned_from': reassignedFrom,
      'reassignment_count': reassignmentCount,
      'retention_days': detentionDays, // Days between unloading and reporting date
    };
  }

  String get formattedAssignedAt {
    final istDate = assignedAt.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd MMM yyyy, hh:mm a').format(istDate);
  }

  String get formattedCompletedAt {
    if (completedAt == null) return 'N/A';
    final istDate = completedAt!.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd MMM yyyy, hh:mm a').format(istDate);
  }

  String get formattedReportingDate {
    if (reportingDate == null) return 'N/A';
    final istDate = reportingDate!.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('dd MMM yyyy').format(istDate);
  }

  int get calculatedDetentionDays {
    // Detention days = Reporting date - Unloading date (calculated when saved)
    return detentionDays ?? 0;
  }

  /// Returns the current stage of the trip for reassignment logging
  String get currentStage {
    if (status == 'completed') return 'completed';
    if (status == 'cancelled') return 'cancelled';
    if (status == 'in_transit') return 'loading';
    return 'assigned';
  }
}
