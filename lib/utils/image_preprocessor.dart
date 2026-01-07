import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  static const double meanR = 0.48145466;
  static const double meanG = 0.4578275;
  static const double meanB = 0.40821073;
  static const double stdR = 0.26862954;
  static const double stdG = 0.26130258;
  static const double stdB = 0.27577711;
  static const int targetSize = 384;

  static Future<List<List<List<double>>>> preprocessImage(File imageFile) async {
    final imageBytes = await imageFile.readAsBytes();
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    final resized = img.copyResize(
      image,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.cubic,
    );

    final normalized = List.generate(
      3,
      (c) => List.generate(
        targetSize,
        (h) => List.generate(targetSize, (w) => 0.0),
      ),
    );

    for (int h = 0; h < targetSize; h++) {
      for (int w = 0; w < targetSize; w++) {
        final pixel = resized.getPixel(w, h);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        normalized[0][h][w] = (r - meanR) / stdR;
        normalized[1][h][w] = (g - meanG) / stdG;
        normalized[2][h][w] = (b - meanB) / stdB;
      }
    }

    return normalized;
  }

  static Future<List<List<List<double>>>> preprocessImageFromBytes(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    final resized = img.copyResize(
      image,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.cubic,
    );

    final normalized = List.generate(
      3,
      (c) => List.generate(
        targetSize,
        (h) => List.generate(targetSize, (w) => 0.0),
      ),
    );

    for (int h = 0; h < targetSize; h++) {
      for (int w = 0; w < targetSize; w++) {
        final pixel = resized.getPixel(w, h);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        normalized[0][h][w] = (r - meanR) / stdR;
        normalized[1][h][w] = (g - meanG) / stdG;
        normalized[2][h][w] = (b - meanB) / stdB;
      }
    }

    return normalized;
  }
}

