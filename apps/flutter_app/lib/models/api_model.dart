class ApiModel {
  final String id;
  final String ownedBy;

  ApiModel({required this.id, required this.ownedBy});

  factory ApiModel.fromJson(Map<String, dynamic> json) {
    return ApiModel(
      id: json['id'] as String,
      ownedBy: (json['owned_by'] ?? json['owner'] ?? 'unknown') as String,
    );
  }
}
