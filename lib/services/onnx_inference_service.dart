import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import '../services/tokenizer_service.dart';
import '../utils/image_preprocessor.dart';

class OnnxInferenceService {
  static bool _isInitialized = false;
  static bool _packageAvailable = false;
  static OrtSession? _visionSession;
  static OrtSession? _decoderSession;

  static const int imageSize = 384;  // BLIP models expect 384×384 input
  static const int maxLength = 30;

  static Future<void> initialize() async {
    if (_isInitialized) {
      print('OnnxInferenceService: Already initialized');
      return;
    }

    try {
      print('OnnxInferenceService: Checking for ONNX runtime package...');
      
      try {
        final onnxPackage = await _checkPackageAvailable();
        _packageAvailable = onnxPackage;

        if (!_packageAvailable) {
          print('OnnxInferenceService: ONNX runtime package not available');
          print('OnnxInferenceService: Please run: flutter pub get');
          print('OnnxInferenceService: And ensure onnxruntime package is in pubspec.yaml');
          _isInitialized = true;
          return;
        }

        print('OnnxInferenceService: ONNX runtime package found, initializing...');
        await _initializeOnnxRuntime();
        _packageAvailable = true; // Mark as available only after successful initialization
        _isInitialized = true;
        print('OnnxInferenceService: Initialization complete - package available: $_packageAvailable');
      } catch (e, stackTrace) {
        print('OnnxInferenceService: Error during initialization: $e');
        print('OnnxInferenceService: Initialization stack trace: $stackTrace');
        _packageAvailable = false;
        _isInitialized = true;
      }
    } catch (e, stackTrace) {
      print('OnnxInferenceService: Fatal error initializing: $e');
      print('OnnxInferenceService: Stack trace: $stackTrace');
      _isInitialized = true;
    }
  }

  static Future<bool> _checkPackageAvailable() async {
    try {
      // Try to initialize OrtEnv to verify package is available
      // If this succeeds, the package is available
      // Note: This will fail if native library is not found
      OrtEnv.instance.init();
      print('OnnxInferenceService: ONNX Runtime package is available');
      return true;
    } catch (e) {
      print('OnnxInferenceService: Error checking package availability: $e');
      print('OnnxInferenceService: This usually means the native library (libonnxruntime.so) is not found');
      print('OnnxInferenceService: Try: flutter clean && flutter pub get && flutter run');
      return false;
    }
  }

  static Future<void> _initializeOnnxRuntime() async {
    try {
      print('OnnxInferenceService: Initializing ONNX Runtime environment...');
      OrtEnv.instance.init();
      print('OnnxInferenceService: ONNX Runtime environment initialized successfully');
      
      // Give the library a moment to fully load
      await Future.delayed(const Duration(milliseconds: 200));
      
      print('OnnxInferenceService: Loading vision model bytes...');
      final visionModelBytes = await rootBundle.load('models/blip_vision_encoder_quantized.onnx');
      print('OnnxInferenceService: Vision model loaded: ${visionModelBytes.lengthInBytes} bytes');
      
      print('OnnxInferenceService: Loading decoder model bytes...');
      final decoderModelBytes = await rootBundle.load('models/blip_text_decoder_quantized.onnx');
      print('OnnxInferenceService: Decoder model loaded: ${decoderModelBytes.lengthInBytes} bytes');

      print('OnnxInferenceService: Creating vision session...');
      final visionOptions = OrtSessionOptions();
      _visionSession = OrtSession.fromBuffer(
        visionModelBytes.buffer.asUint8List(),
        visionOptions,
      );
      print('OnnxInferenceService: Vision session created!');

      print('OnnxInferenceService: Creating decoder session...');
      final decoderOptions = OrtSessionOptions();
      _decoderSession = OrtSession.fromBuffer(
        decoderModelBytes.buffer.asUint8List(),
        decoderOptions,
      );
      print('OnnxInferenceService: Decoder session created!');
      
      // Initialize tokenizer
      print('OnnxInferenceService: Initializing tokenizer...');
      try {
        await TokenizerService.initialize();
        print('OnnxInferenceService: Tokenizer initialized successfully');
      } catch (e) {
        print('OnnxInferenceService: Warning - Tokenizer initialization failed: $e');
        print('OnnxInferenceService: Caption generation will work but token decoding may fail');
      }
      
      print('OnnxInferenceService: All models loaded successfully');
    } catch (e, stackTrace) {
      print('OnnxInferenceService: Error loading ONNX models: $e');
      print('OnnxInferenceService: Stack trace: $stackTrace');
      _visionSession?.release();
      _decoderSession?.release();
      _visionSession = null;
      _decoderSession = null;
      rethrow;
    }
  }

  static Future<String> generateCaption(Uint8List imageBytes) async {
    // Validate input
    if (imageBytes.isEmpty) {
      throw ArgumentError('Image bytes cannot be empty');
    }
    
    if (!_isInitialized) {
      await initialize();
    }

    if (!_packageAvailable) {
      final errorMsg = 'ONNX runtime package is not available. Please install onnxruntime package and run flutter pub get.';
      print('OnnxInferenceService: $errorMsg');
      throw UnimplementedError(errorMsg);
    }

    try {
      print('OnnxInferenceService: Starting caption generation...');
      print('OnnxInferenceService: Image bytes: ${imageBytes.length}');
      
      final preprocessedImage = await ImagePreprocessor.preprocessImageFromBytes(imageBytes);
      
      print('OnnxInferenceService: Image preprocessed successfully');
      
      final visionFeatures = await _runVisionEncoder(preprocessedImage);
      
      final caption = await _generateCaption(visionFeatures);
      
      if (caption.isEmpty) {
        throw StateError('Generated empty caption');
      }
      
      print('OnnxInferenceService: Caption generated: "$caption"');
      return caption;
    } catch (e, stackTrace) {
      print('OnnxInferenceService: Error generating caption: $e');
      print('OnnxInferenceService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Future<OrtValueTensor?> _runVisionEncoder(
    List<List<List<double>>> preprocessedImage,
  ) async {
    if (!_isInitialized || _visionSession == null) {
      throw Exception('Models not initialized');
    }

    try {
      print('OnnxInferenceService: Preparing vision encoder input...');
      final inputShape = [1, 3, 384, 384];
      final inputData = Float32List(1 * 3 * 384 * 384);

      for (int c = 0; c < 3; c++) {
        for (int h = 0; h < 384; h++) {
          for (int w = 0; w < 384; w++) {
            final index = c * 384 * 384 + h * 384 + w;
            inputData[index] = preprocessedImage[c][h][w];
          }
        }
      }

      print('OnnxInferenceService: Creating input tensor...');
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        inputData,
        inputShape,
      );

      final inputs = {'pixel_values': inputTensor};
      final runOptions = OrtRunOptions();
      
      print('OnnxInferenceService: Running vision encoder...');
      final outputs = await _visionSession!.runAsync(runOptions, inputs);
      
      inputTensor.release();
      runOptions.release();

      if (outputs == null || outputs.isEmpty) {
        throw Exception('Vision encoder returned no outputs');
      }

      print('OnnxInferenceService: Vision encoder completed!');
      return outputs[0] as OrtValueTensor?;
    } catch (e) {
      print('OnnxInferenceService: Vision encoder inference failed: $e');
      throw Exception('Vision encoder inference failed: $e');
    }
  }

  static Future<String> _generateCaption(
    OrtValueTensor? visionFeatures,
  ) async {
    if (!_isInitialized || _decoderSession == null) {
      throw Exception('Models not initialized');
    }

    if (visionFeatures == null) {
      throw Exception('Vision features is null');
    }

    try {
      print('OnnxInferenceService: Starting caption generation...');
      final clsTokenId = TokenizerService.getClsTokenId();
      final sepTokenId = TokenizerService.getSepTokenId();

      List<int> inputIds = [clsTokenId];
      final maxLength = 30;

      for (int i = 0; i < maxLength; i++) {
        final attentionMask = List<int>.filled(inputIds.length, 1);

        final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
          Int64List.fromList(inputIds),
          [1, inputIds.length],
        );

        final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(
          Int64List.fromList(attentionMask),
          [1, attentionMask.length],
        );

        final inputs = <String, OrtValueTensor>{
          'input_ids': inputIdsTensor,
          'attention_mask': attentionMaskTensor,
          'encoder_hidden_states': visionFeatures,
        };

        final runOptions = OrtRunOptions();
        final outputs = await _decoderSession!.runAsync(runOptions, inputs);

        inputIdsTensor.release();
        attentionMaskTensor.release();
        runOptions.release();

        if (outputs == null || outputs.isEmpty) {
          print('OnnxInferenceService: Decoder returned no outputs at step $i');
          break;
        }

        final logits = outputs[0] as OrtValueTensor?;
        if (logits == null) {
          print('OnnxInferenceService: Logits is null at step $i');
          break;
        }

        final logitsData = logits.value as List;
        outputs.forEach((element) => element?.release());

        if (logitsData.isEmpty || logitsData[0] is! List) {
          break;
        }

        final lastTokenLogits = (logitsData[0] as List).last as List;
        int nextTokenId = 0;
        double maxLogit = double.negativeInfinity;

        for (int j = 0; j < lastTokenLogits.length; j++) {
          final logit = (lastTokenLogits[j] as num).toDouble();
          if (logit > maxLogit) {
            maxLogit = logit;
            nextTokenId = j;
          }
        }

        if (nextTokenId == sepTokenId) {
          print('OnnxInferenceService: Generated ${inputIds.length - 1} tokens');
          break;
        }

        inputIds.add(nextTokenId);
      }

      final caption = TokenizerService.decodeTokens(inputIds.skip(1).toList());
      print('OnnxInferenceService: Caption generated: $caption');
      return caption;
    } catch (e) {
      print('OnnxInferenceService: Caption generation failed: $e');
      throw Exception('Caption generation failed: $e');
    }
  }

  static void dispose() {
    _visionSession?.release();
    _decoderSession?.release();
    _visionSession = null;
    _decoderSession = null;
    _isInitialized = false;
    _packageAvailable = false;
    OrtEnv.instance.release();
    print('OnnxInferenceService: Disposed');
  }
}
