import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img;
import '../models/image_item.dart';

class MediaService {
  // Cache for thumbnails to avoid repeated loads
  static final Map<String, Uint8List> _thumbnailCache = {};
  static const int _maxCacheSize = 200; // Limit cache size to prevent memory issues
  static Future<bool> requestPermissions() async {
    final result = await PhotoManager.requestPermissionExtend();
    return result.isAuth;
  }

  static Future<List<AssetPathEntity>> getAlbums() async {
    return await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );
  }

  static Future<List<AssetEntity>> getImages({
    int page = 0,
    int size = 100,
    AssetPathEntity? album,
  }) async {
    final path = album ??
        (await PhotoManager.getAssetPathList(
          type: RequestType.image,
          hasAll: true,
        ))
            .firstOrNull;

    if (path == null) return [];

    return await path.getAssetListPaged(
      page: page,
      size: size,
    );
  }

  static Future<List<ImageItem>> getAllImages({
    AssetPathEntity? album,
  }) async {
    final images = <ImageItem>[];
    int page = 0;
    const pageSize = 100;

    while (true) {
      final assets = await getImages(page: page, size: pageSize, album: album);
      if (assets.isEmpty) break;

      images.addAll(
        assets.map(
          (asset) => ImageItem(
            id: asset.id,
            asset: asset,
          ),
        ),
      );

      if (assets.length < pageSize) break;
      page++;
    }

    return images;
  }

  static Future<Uint8List?> getThumbnail(
    AssetEntity asset, {
    int size = 200,
  }) async {
    // Check cache first
    final cacheKey = '${asset.id}_$size';
    if (_thumbnailCache.containsKey(cacheKey)) {
      return _thumbnailCache[cacheKey];
    }

    // Load thumbnail
    final thumbnail = await asset.thumbnailDataWithSize(
      ThumbnailSize.square(size),
    );

    // Cache the result if we got one
    if (thumbnail != null) {
      // Limit cache size - remove oldest entries if cache is too large
      if (_thumbnailCache.length >= _maxCacheSize) {
        // Remove first entry (simple FIFO)
        final firstKey = _thumbnailCache.keys.first;
        _thumbnailCache.remove(firstKey);
      }
      _thumbnailCache[cacheKey] = thumbnail;
    }

    return thumbnail;
  }

  /// Clear the thumbnail cache to free memory
  static void clearThumbnailCache() {
    _thumbnailCache.clear();
  }

  static Future<Uint8List?> getFullImage(AssetEntity asset) async {
    return await asset.originBytes;
  }

  static Future<Uint8List?> resizeImage(
    Uint8List imageBytes,
    int width,
    int height,
  ) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final resized = img.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );

      return Uint8List.fromList(img.encodePng(resized));
    } catch (e) {
      print('Error resizing image: $e');
      return null;
    }
  }
}

