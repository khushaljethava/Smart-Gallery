import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'services/tokenizer_service.dart';

/// Simple test script to debug ONNX model inference
/// Run this with: flutter run -d <device> --target=lib/test_onnx_inference.dart
void main() async {
  print('=' * 60);
  print('ONNX Inference Test Script');
  print('=' * 60);
  
  try {
    // Step 1: Initialize ONNX Runtime
    print('\n[Step 1] Initializing ONNX Runtime...');
    OrtEnv.instance.init();
    print('✓ ONNX Runtime initialized');
    
    // Step 2: Load models
    print('\n[Step 2] Loading ONNX models...');
    
    print('  Loading vision encoder...');
    final visionAsset = await rootBundle.load('models/blip_vision_encoder_quantized.onnx');
    final visionBytes = visionAsset.buffer.asUint8List();
    print('  Vision encoder file size: ${visionBytes.length} bytes');
    
    final visionSessionOptions = OrtSessionOptions();
    final visionSession = OrtSession.fromBuffer(visionBytes, visionSessionOptions);
    print('✓ Vision encoder loaded');
    
    print('  Loading text decoder...');
    final decoderAsset = await rootBundle.load('models/blip_text_decoder_quantized.onnx');
    final decoderBytes = decoderAsset.buffer.asUint8List();
    print('  Text decoder file size: ${decoderBytes.length} bytes');
    
    final decoderSessionOptions = OrtSessionOptions();
    final decoderSession = OrtSession.fromBuffer(decoderBytes, decoderSessionOptions);
    print('✓ Text decoder loaded');
    
    // Step 3: Create test image (simple 384x384 RGB image)
    print('\n[Step 3] Creating test image...');
    final testImage = img.Image(width: 384, height: 384);
    // Fill with a simple pattern
    for (int y = 0; y < 384; y++) {
      for (int x = 0; x < 384; x++) {
        final r = (x % 256).toInt();
        final g = (y % 256).toInt();
        final b = ((x + y) % 256).toInt();
        testImage.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }
    print('✓ Test image created: 384x384');
    
    // Step 4: Preprocess image
    print('\n[Step 4] Preprocessing image...');
    const imageSize = 384;
    const mean = [0.48145466, 0.4578275, 0.40821073];
    const std = [0.26862954, 0.26130258, 0.27577711];
    
    final normalized = List<double>.filled(3 * imageSize * imageSize, 0.0);
    for (int y = 0; y < imageSize; y++) {
      for (int x = 0; x < imageSize; x++) {
        final pixel = testImage.getPixel(x, y);
        final r = pixel.r.toDouble() / 255.0;
        final g = pixel.g.toDouble() / 255.0;
        final b = pixel.b.toDouble() / 255.0;
        
        final idx = y * imageSize + x;
        normalized[idx] = (r - mean[0]) / std[0];
        normalized[idx + imageSize * imageSize] = (g - mean[1]) / std[1];
        normalized[idx + 2 * imageSize * imageSize] = (b - mean[2]) / std[2];
      }
    }
    print('✓ Image preprocessed: ${normalized.length} values');
    print('  Sample values: ${normalized.take(10).toList()}');
    
    // Step 5: Create input tensor for vision encoder
    print('\n[Step 5] Creating vision encoder input tensor...');
    final inputShape = [1, 3, imageSize, imageSize];
    final inputData = Float32List(1 * 3 * imageSize * imageSize);
    
    // Convert from CHW to NCHW format
    for (int c = 0; c < 3; c++) {
      for (int h = 0; h < imageSize; h++) {
        for (int w = 0; w < imageSize; w++) {
          final srcIdx = c * imageSize * imageSize + h * imageSize + w;
          final dstIdx = c * imageSize * imageSize + h * imageSize + w;
          inputData[dstIdx] = normalized[srcIdx].toDouble();
        }
      }
    }
    print('✓ Input tensor data prepared: ${inputData.length} values');
    print('  Input shape: $inputShape');
    print('  Sample input values: ${inputData.take(10).toList()}');
    
    // Try to create tensor - test different methods
    OrtValueTensor? inputTensor;
    try {
      print('  Attempting to create tensor with createTensorWithDataList...');
      final inputDataList = inputData.map((e) => e.toDouble()).toList();
      inputTensor = OrtValueTensor.createTensorWithDataList(
        inputDataList,
        List<int>.from(inputShape),
      );
      print('✓ Tensor created successfully');
    } catch (e) {
      print('✗ Failed to create tensor: $e');
      print('  Trying alternative method...');
      // Try alternative if available
      rethrow;
    }
    
    // Step 6: Run vision encoder inference
    print('\n[Step 6] Running vision encoder inference...');
    try {
      final runOptions = OrtRunOptions();
      final inputs = {'pixel_values': inputTensor!};
      print('  Input keys: ${inputs.keys.toList()}');
      print('  Running inference...');
      
      final outputs = visionSession.run(runOptions, inputs);
      print('✓ Vision encoder inference completed');
      print('  Output count: ${outputs.length}');
      
      if (outputs.isEmpty) {
        print('✗ ERROR: No outputs from vision encoder!');
        return;
      }
      
      final encoderOutput = outputs[0];
      if (encoderOutput == null) {
        print('✗ ERROR: Vision encoder output is null!');
        return;
      }
      
      print('  Output type: ${encoderOutput.runtimeType}');
      
      // Try to access the value
      try {
        final encoderValue = encoderOutput.value;
        print('  Output value type: ${encoderValue.runtimeType}');
        
        if (encoderValue is List) {
          print('  Output is a List with ${encoderValue.length} elements');
          print('  First 10 values: ${encoderValue.take(10).toList()}');
          
          // Shape information - BLIP vision encoder output is [1, 577, 768]
          print('  Assuming BLIP shape: [1, 577, 768]');
          if (encoderValue.length == 1 * 577 * 768) {
            print('  ✓ Output length matches expected shape!');
          } else {
            print('  ⚠ Output length: ${encoderValue.length}, expected: ${1 * 577 * 768}');
          }
        } else {
          print('  Output value is not a List: $encoderValue');
        }
      } catch (e) {
        print('  Could not access output value: $e');
        print('  Trying alternative access methods...');
      }
      
      // Clean up
      inputTensor.release();
      runOptions.release();
      for (final output in outputs) {
        output?.release();
      }
      
    } catch (e, stackTrace) {
      print('✗ ERROR in vision encoder inference: $e');
      print('  Stack trace: $stackTrace');
      inputTensor?.release();
      return;
    }
    
    // Step 7: Test text decoder (simplified - just test if it loads)
    print('\n[Step 7] Testing text decoder setup...');
    print('  Decoder session created: ${decoderSession != null}');
    
    // Step 8: Test tokenizer
    print('\n[Step 8] Testing tokenizer...');
    try {
      await TokenizerService.initialize();
      print('✓ Tokenizer initialized');
      
      // Test decoding
      final testTokens = [TokenizerService.getClsTokenId(), 100, 200, TokenizerService.getSepTokenId()]; // CLS, some tokens, SEP
      final decoded = TokenizerService.decodeTokens(testTokens);
      print('  Test decode: $decoded');
    } catch (e) {
      print('✗ Tokenizer error: $e');
    }
    
    // Cleanup
    print('\n[Cleanup] Releasing resources...');
    visionSession.release();
    decoderSession.release();
    visionSessionOptions.release();
    decoderSessionOptions.release();
    print('✓ Resources released');
    
    print('\n' + '=' * 60);
    print('Test completed!');
    print('=' * 60);
    
  } catch (e, stackTrace) {
    print('\n✗ FATAL ERROR: $e');
    print('Stack trace: $stackTrace');
  }
}

