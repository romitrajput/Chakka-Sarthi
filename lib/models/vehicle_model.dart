class VehicleModel {
  final String id;
  final String vehicleNumber;
  final String companyCode;
  final String status; // available | in_transit | maintenance
  final String? maintenanceReason;
  final DateTime? maintenanceFrom;
  final DateTime? maintenanceExpectedReturn;
  final DateTime createdAt;

  VehicleModel({
    required this.id,
    required this.vehicleNumber,
    required this.companyCode,
    required this.status,
    this.maintenanceReason,
    this.maintenanceFrom,
    this.maintenanceExpectedReturn,
    required this.createdAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      vehicleNumber: json['vehicle_number'] as String,
      companyCode: json['company_code'] as String,
      status: json['status'] as String,
      maintenanceReason: json['maintenance_reason'] as String?,
      maintenanceFrom: json['maintenance_from'] != null
          ? DateTime.parse(json['maintenance_from'] as String)
          : null,
      maintenanceExpectedReturn: json['maintenance_expected_return'] != null
          ? DateTime.parse(json['maintenance_expected_return'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_number': vehicleNumber,
      'company_code': companyCode,
      'status': status,
      'maintenance_reason': maintenanceReason,
      'maintenance_from': maintenanceFrom?.toIso8601String(),
      'maintenance_expected_return': maintenanceExpectedReturn?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
