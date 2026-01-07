import 'package:hive_flutter/hive_flutter.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/image_item.dart';

class CaptionRepository {
  static const String _boxName = 'captions';
  static Box? _box;

  static Future<void> initialize() async {
    _box = await Hive.openBox(_boxName);
  }

  static Future<void> saveCaption(ImageItem imageItem) async {
    if (_box == null) await initialize();
    await _box!.put(imageItem.id, imageItem.toJson());
  }

  /// Safely convert Hive's dynamic map to Map<String, dynamic>
  static Map<String, dynamic> _convertMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw ArgumentError('Data is not a Map');
  }

  static Future<ImageItem?> getImageItem(String id, AssetEntity asset) async {
    if (_box == null) await initialize();
    final data = _box!.get(id);
    if (data == null) return null;
    return ImageItem.fromJson(_convertMap(data), asset);
  }

  static Future<String?> getCaption(String id) async {
    if (_box == null) await initialize();
    final data = _box!.get(id);
    if (data == null) return null;
    final json = _convertMap(data);
    return json['caption'] as String?;
  }

  static Future<void> updateFavorite(String id, bool isFavorite) async {
    if (_box == null) await initialize();
    final data = _box!.get(id);
    if (data != null) {
      final json = _convertMap(data);
      json['isFavorite'] = isFavorite;
      await _box!.put(id, json);
    }
  }

  static Future<void> addTag(String id, String tag) async {
    if (_box == null) await initialize();
    final data = _box!.get(id);
    if (data != null) {
      final json = _convertMap(data);
      final tags = (json['tags'] as List<dynamic>?)?.cast<String>() ?? [];
      if (!tags.contains(tag)) {
        tags.add(tag);
        json['tags'] = tags;
        await _box!.put(id, json);
      }
    }
  }

  static Future<List<String>> searchByCaptionIds(String query) async {
    if (_box == null) await initialize();
    final results = <String>[];
    final queryLower = query.toLowerCase();

    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null) {
        final json = _convertMap(data);
        final caption = json['caption'] as String?;
        if (caption != null && caption.toLowerCase().contains(queryLower)) {
          results.add(key as String);
        }
      }
    }

    return results;
  }

  static Future<List<String>> getFavoriteIds() async {
    if (_box == null) await initialize();
    final results = <String>[];

    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null) {
        final json = _convertMap(data);
        if (json['isFavorite'] == true) {
          results.add(key as String);
        }
      }
    }

    return results;
  }

  static Future<bool> hasCaption(String id) async {
    if (_box == null) await initialize();
    final data = _box!.get(id);
    if (data == null) return false;
    final json = _convertMap(data);
    return json['caption'] != null;
  }
}

