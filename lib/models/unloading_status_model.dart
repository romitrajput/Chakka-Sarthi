class UnloadingStatusModel {
  final String? id;
  final String ticketId;
  final double unloadingWeightKgs;
  final DateTime unloadingDate;
  final double shortageKgs;
  final DateTime? submittedAt;

  UnloadingStatusModel({
    this.id,
    required this.ticketId,
    required this.unloadingWeightKgs,
    required this.unloadingDate,
    required this.shortageKgs,
    this.submittedAt,
  });

  factory UnloadingStatusModel.fromJson(Map<String, dynamic> json) {
    return UnloadingStatusModel(
      id: json['id'] as String?,
      ticketId: json['ticket_id'] as String,
      unloadingWeightKgs: (json['unloading_weight_kgs'] as num).toDouble(),
      unloadingDate: DateTime.parse(json['unloading_date'] as String),
      shortageKgs: (json['shortage_kgs'] as num).toDouble(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'ticket_id': ticketId,
      'unloading_weight_kgs': unloadingWeightKgs,
      'unloading_date': unloadingDate.toIso8601String(),
      'shortage_kgs': shortageKgs,
      'submitted_at': submittedAt?.toIso8601String(),
    };
  }
}
