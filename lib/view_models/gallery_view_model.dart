import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/image_item.dart';
import '../services/media_service.dart';
import '../services/caption_processing_service.dart';
import '../repositories/caption_repository.dart';

class GalleryViewModel extends StateNotifier<AsyncValue<List<ImageItem>>> {
  GalleryViewModel() : super(const AsyncValue.loading()) {
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      state = const AsyncValue.loading();
      final images = await MediaService.getAllImages();
      
      // Load captions in parallel to avoid blocking the main thread
      // Process in batches to prevent overwhelming the system
      const batchSize = 50;
      for (int i = 0; i < images.length; i += batchSize) {
        final batch = images.skip(i).take(batchSize).toList();
        await Future.wait(
          batch.map((image) async {
            final caption = await CaptionRepository.getCaption(image.id);
            if (caption != null) {
              image.caption = caption;
            }
            // Yield control to allow UI updates
            await Future.delayed(Duration.zero);
          }),
        );
        // Update state after each batch to show progress
        if (i + batchSize < images.length) {
          state = AsyncValue.data(List<ImageItem>.from(images));
          // Yield to main thread
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
      
      state = AsyncValue.data(images);
      
      // Start background processing without awaiting
      CaptionProcessingService.processImagesInBackground(images);
      _listenToCaptionProgress();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void _listenToCaptionProgress() {
    CaptionProcessingService.progressStream.listen((updatedImage) {
      _updateItem(updatedImage);
    });
  }

  Future<void> refresh() async {
    await _loadImages();
  }


  Future<void> toggleFavorite(ImageItem imageItem) async {
    final updated = imageItem.copyWith(isFavorite: !imageItem.isFavorite);
    await CaptionRepository.updateFavorite(updated.id, updated.isFavorite);
    _updateItem(updated);
  }

  void _updateItem(ImageItem updated) {
    state.whenData((images) {
      final index = images.indexWhere((img) => img.id == updated.id);
      if (index != -1) {
        final newImages = List<ImageItem>.from(images);
        newImages[index] = updated;
        state = AsyncValue.data(newImages);
      }
    });
  }
}

final galleryProvider = StateNotifierProvider<GalleryViewModel, AsyncValue<List<ImageItem>>>(
  (ref) => GalleryViewModel(),
);

