import 'package:photo_manager/photo_manager.dart';

class ImageItem {
  final String id;
  final AssetEntity asset;
  String? caption;
  bool isFavorite;
  final List<String> tags;
  final DateTime? captionGeneratedAt;
  bool isCaptionGenerating;

  ImageItem({
    required this.id,
    required this.asset,
    this.caption,
    this.isFavorite = false,
    List<String>? tags,
    this.captionGeneratedAt,
    this.isCaptionGenerating = false,
  }) : tags = tags ?? [];

  ImageItem copyWith({
    String? id,
    AssetEntity? asset,
    String? caption,
    bool? isFavorite,
    List<String>? tags,
    DateTime? captionGeneratedAt,
    bool? isCaptionGenerating,
  }) {
    return ImageItem(
      id: id ?? this.id,
      asset: asset ?? this.asset,
      caption: caption ?? this.caption,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      captionGeneratedAt: captionGeneratedAt ?? this.captionGeneratedAt,
      isCaptionGenerating: isCaptionGenerating ?? this.isCaptionGenerating,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetId': asset.id,
      'caption': caption,
      'isFavorite': isFavorite,
      'tags': tags,
      'captionGeneratedAt': captionGeneratedAt?.toIso8601String(),
      'isCaptionGenerating': isCaptionGenerating,
    };
  }

  factory ImageItem.fromJson(Map<String, dynamic> json, AssetEntity? asset) {
    if (asset == null) {
      throw ArgumentError('AssetEntity cannot be null');
    }
    return ImageItem(
      id: json['id'] as String,
      asset: asset,
      caption: json['caption'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      captionGeneratedAt: json['captionGeneratedAt'] != null
          ? DateTime.parse(json['captionGeneratedAt'] as String)
          : null,
      isCaptionGenerating: json['isCaptionGenerating'] as bool? ?? false,
    );
  }
}

