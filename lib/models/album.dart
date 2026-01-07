class Album {
  final String id;
  final String name;
  final String? description;
  final List<String> imageIds;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Album({
    required this.id,
    required this.name,
    this.description,
    List<String>? imageIds,
    DateTime? createdAt,
    this.updatedAt,
  })  : imageIds = imageIds ?? [],
        createdAt = createdAt ?? DateTime.now();

  Album copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? imageIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Album(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageIds: imageIds ?? this.imageIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageIds': imageIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      imageIds: (json['imageIds'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

