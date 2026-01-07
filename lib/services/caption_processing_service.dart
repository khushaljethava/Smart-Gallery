import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../models/image_item.dart';
import '../services/media_service.dart';
import '../services/onnx_inference_service.dart';
import '../repositories/caption_repository.dart';

class CaptionProcessingService {
  static bool _isProcessing = false;
  static final List<ImageItem> _queue = [];
  static StreamController<ImageItem>? _progressController;
  static Stream<ImageItem>? _progressStream;

  static Stream<ImageItem> get progressStream {
    _progressController ??= StreamController<ImageItem>.broadcast();
    _progressStream ??= _progressController!.stream;
    return _progressStream!;
  }

  static bool get isProcessing => _isProcessing;

  static Future<void> processImagesInBackground(List<ImageItem> images) async {
    if (_isProcessing) {
      print('CaptionProcessingService: Already processing, skipping...');
      return;
    }

    print('CaptionProcessingService: Starting background processing for ${images.length} images');
    _isProcessing = true;
    final imagesToProcess = <ImageItem>[];

    for (final image in images) {
      final existingCaption = await CaptionRepository.getCaption(image.id);
      if (existingCaption == null) {
        imagesToProcess.add(image);
      }
    }

    print('CaptionProcessingService: Found ${imagesToProcess.length} images without captions');

    if (imagesToProcess.isEmpty) {
      print('CaptionProcessingService: No images to process');
      _isProcessing = false;
      return;
    }

    _queue.clear();
    _queue.addAll(imagesToProcess);

    int processed = 0;
    for (final image in imagesToProcess) {
      try {
        print('CaptionProcessingService: Processing image ${++processed}/${imagesToProcess.length} (${image.id})');
        await _processImage(image);
        
        // Add delay between images to prevent blocking main thread
        // This gives UI time to render between processing
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e, stackTrace) {
        print('CaptionProcessingService: Error processing image ${image.id}: $e');
        print('CaptionProcessingService: Stack trace: $stackTrace');
      }
    }

    print('CaptionProcessingService: Finished processing all images');
    _isProcessing = false;
  }

  static Future<void> _processImage(ImageItem image) async {
    try {
      print('CaptionProcessingService: Starting processing for image ${image.id}');
      final updatedItem = image.copyWith(isCaptionGenerating: true);
      _notifyProgress(updatedItem);

      print('CaptionProcessingService: Loading full image for ${image.id}');
      final imageBytes = await MediaService.getFullImage(image.asset);
      if (imageBytes == null) {
        print('CaptionProcessingService: Failed to load image bytes for ${image.id}');
        final errorItem = image.copyWith(isCaptionGenerating: false);
        _notifyProgress(errorItem);
        return;
      }
      print('CaptionProcessingService: Loaded ${imageBytes.length} bytes for ${image.id}');

      // Run heavy image processing on compute (separate thread)
      print('CaptionProcessingService: Resizing image to 384x384 for ${image.id}');
      final resizedBytes = await compute(_resizeImageInIsolate, imageBytes);
      if (resizedBytes == null) {
        print('CaptionProcessingService: Failed to resize image for ${image.id}');
        final errorItem = image.copyWith(isCaptionGenerating: false);
        _notifyProgress(errorItem);
        return;
      }
      print('CaptionProcessingService: Resized to ${resizedBytes.length} bytes for ${image.id}');

      print('CaptionProcessingService: Generating caption for ${image.id}');
      final caption = await OnnxInferenceService.generateCaption(Uint8List.fromList(resizedBytes));
      print('CaptionProcessingService: Generated caption for ${image.id}: "$caption"');

      final finalItem = updatedItem.copyWith(
        caption: caption,
        isCaptionGenerating: false,
        captionGeneratedAt: DateTime.now(),
      );

      print('CaptionProcessingService: Saving caption to database for ${image.id}');
      await CaptionRepository.saveCaption(finalItem);
      _notifyProgress(finalItem);
      print('CaptionProcessingService: Successfully processed image ${image.id}');
    } catch (e, stackTrace) {
      print('CaptionProcessingService: Exception processing image ${image.id}: $e');
      print('CaptionProcessingService: Stack trace: $stackTrace');
      
      // Provide fallback caption
      final errorItem = image.copyWith(
        caption: _generateFallbackCaption(e),
        isCaptionGenerating: false,
        captionGeneratedAt: DateTime.now(),
      );
      
      // Save to database so it persists
      print('CaptionProcessingService: Saving fallback caption to database for ${image.id}');
      await CaptionRepository.saveCaption(errorItem);
      _notifyProgress(errorItem);
    }
  }

  static String _generateFallbackCaption(dynamic error) {
    if (error is UnimplementedError) {
      return 'Caption generation not available in this version';
    }
    return 'Unable to generate caption for this image';
  }

  static void _notifyProgress(ImageItem image) {
    _progressController?.add(image);
  }

  static void dispose() {
    _progressController?.close();
    _progressController = null;
    _progressStream = null;
    _isProcessing = false;
    _queue.clear();
  }
}

/// Top-level function to resize image in a separate isolate
/// This prevents blocking the main thread during heavy image processing
Future<Uint8List?> _resizeImageInIsolate(Uint8List imageBytes) async {
  try {
    return await MediaService.resizeImage(
      imageBytes,
      384,  // Correct size for BLIP model
      384,
    );
  } catch (e) {
    print('CaptionProcessingService: Error in isolate resizing image: $e');
    return null;
  }
}
