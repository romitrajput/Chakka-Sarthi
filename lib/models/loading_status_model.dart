class LoadingStatusModel {
  final String? id;
  final String ticketId;
  final String vehicleNumber;
  final String driverName;
  final String lrNumber;
  final String journeyFrom;
  final String journeyTo;
  final String consigneeName;
  final String product;
  final double loadingWeightKgs;
  final DateTime creationDate;
  final DateTime? submittedAt;

  LoadingStatusModel({
    this.id,
    required this.ticketId,
    required this.vehicleNumber,
    required this.driverName,
    required this.lrNumber,
    required this.journeyFrom,
    required this.journeyTo,
    required this.consigneeName,
    required this.product,
    required this.loadingWeightKgs,
    required this.creationDate,
    this.submittedAt,
  });

  factory LoadingStatusModel.fromJson(Map<String, dynamic> json) {
    return LoadingStatusModel(
      id: json['id'] as String?,
      ticketId: json['ticket_id'] as String,
      vehicleNumber: json['vehicle_number'] as String,
      driverName: json['driver_name'] as String,
      lrNumber: json['lr_number'] as String,
      journeyFrom: json['journey_from'] as String,
      journeyTo: json['journey_to'] as String,
      consigneeName: json['consignee_name'] as String,
      product: json['product'] as String,
      loadingWeightKgs: (json['loading_weight_kgs'] as num).toDouble(),
      creationDate: DateTime.parse(json['creation_date'] as String),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'ticket_id': ticketId,
      'vehicle_number': vehicleNumber,
      'driver_name': driverName,
      'lr_number': lrNumber,
      'journey_from': journeyFrom,
      'journey_to': journeyTo,
      'consignee_name': consigneeName,
      'product': product,
      'loading_weight_kgs': loadingWeightKgs,
      'creation_date': creationDate.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
    };
  }
}
