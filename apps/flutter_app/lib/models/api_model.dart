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

class ModelFetchResult {
  final List<ApiModel> models;
  final String? errorMessage;

  const ModelFetchResult({
    required this.models,
    this.errorMessage,
  });

  bool get isSuccess => errorMessage == null;

  const ModelFetchResult.success(this.models)
      : errorMessage = null;

  const ModelFetchResult.failure(this.errorMessage)
      : models = const [];
}
