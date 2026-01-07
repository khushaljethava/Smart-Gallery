import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import '../services/tokenizer_service.dart';

/// Simple test screen to debug ONNX model inference
/// Add this to your app navigation to test ONNX inference
class TestOnnxScreen extends StatefulWidget {
  const TestOnnxScreen({super.key});

  @override
  State<TestOnnxScreen> createState() => _TestOnnxScreenState();
}

class _TestOnnxScreenState extends State<TestOnnxScreen> {
  final List<String> _logs = [];
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
    print(message);
  }

  Future<void> _runTest() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    try {
      _addLog('=' * 60);
      _addLog('ONNX Inference Test');
      _addLog('=' * 60);

      // Step 1: Initialize ONNX Runtime
      _addLog('\n[Step 1] Initializing ONNX Runtime...');
      OrtEnv.instance.init();
      _addLog('✓ ONNX Runtime initialized');

      // Step 2: Load models
      _addLog('\n[Step 2] Loading ONNX models...');

      _addLog('  Loading vision encoder...');
      final visionAsset = await rootBundle.load('models/blip_vision_encoder_quantized.onnx');
      final visionBytes = visionAsset.buffer.asUint8List();
      _addLog('  Vision encoder file size: ${visionBytes.length} bytes');

      final visionSessionOptions = OrtSessionOptions();
      final visionSession = OrtSession.fromBuffer(visionBytes, visionSessionOptions);
      _addLog('✓ Vision encoder loaded');

      _addLog('  Loading text decoder...');
      final decoderAsset = await rootBundle.load('models/blip_text_decoder_quantized.onnx');
      final decoderBytes = decoderAsset.buffer.asUint8List();
      _addLog('  Text decoder file size: ${decoderBytes.length} bytes');

      final decoderSessionOptions = OrtSessionOptions();
      final decoderSession = OrtSession.fromBuffer(decoderBytes, decoderSessionOptions);
      _addLog('✓ Text decoder loaded');

      // Step 3: Create test image
      _addLog('\n[Step 3] Creating test image...');
      final testImage = img.Image(width: 384, height: 384);
      for (int y = 0; y < 384; y++) {
        for (int x = 0; x < 384; x++) {
          final r = (x % 256).toInt();
          final g = (y % 256).toInt();
          final b = ((x + y) % 256).toInt();
          testImage.setPixel(x, y, img.ColorRgb8(r, g, b));
        }
      }
      _addLog('✓ Test image created: 384x384');

      // Step 4: Preprocess image
      _addLog('\n[Step 4] Preprocessing image...');
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
      _addLog('✓ Image preprocessed: ${normalized.length} values');

      // Step 5: Create input tensor
      _addLog('\n[Step 5] Creating vision encoder input tensor...');
      final inputShape = [1, 3, imageSize, imageSize];
      final inputData = Float32List(1 * 3 * imageSize * imageSize);

      for (int c = 0; c < 3; c++) {
        for (int h = 0; h < imageSize; h++) {
          for (int w = 0; w < imageSize; w++) {
            final srcIdx = c * imageSize * imageSize + h * imageSize + w;
            final dstIdx = c * imageSize * imageSize + h * imageSize + w;
            inputData[dstIdx] = normalized[srcIdx].toDouble();
          }
        }
      }
      _addLog('✓ Input tensor data prepared: ${inputData.length} values');
      _addLog('  Input shape: $inputShape');

      // Try to create tensor
      OrtValueTensor? inputTensor;
      try {
        _addLog('  Attempting to create tensor...');
        final inputDataList = inputData.map((e) => e.toDouble()).toList();
        inputTensor = OrtValueTensor.createTensorWithDataList(
          inputDataList,
          List<int>.from(inputShape),
        );
        _addLog('✓ Tensor created successfully');
      } catch (e) {
        _addLog('✗ Failed to create tensor: $e');
        _addLog('  Error type: ${e.runtimeType}');
        return;
      }

      // Step 6: Run vision encoder inference
      _addLog('\n[Step 6] Running vision encoder inference...');
      try {
        final runOptions = OrtRunOptions();
        final inputs = {'pixel_values': inputTensor!};
        _addLog('  Input keys: ${inputs.keys.toList()}');
        _addLog('  Running inference...');

        final outputs = visionSession.run(runOptions, inputs);
        _addLog('✓ Vision encoder inference completed');
        _addLog('  Output count: ${outputs.length}');

        if (outputs.isEmpty) {
          _addLog('✗ ERROR: No outputs from vision encoder!');
          return;
        }

        final encoderOutput = outputs[0];
        if (encoderOutput == null) {
          _addLog('✗ ERROR: Vision encoder output is null!');
          return;
        }

        _addLog('  Output type: ${encoderOutput.runtimeType}');

        // Try to access the value
        try {
          final encoderValue = encoderOutput.value;
          _addLog('  Output value type: ${encoderValue.runtimeType}');

          if (encoderValue is List) {
            _addLog('  Output is a List with ${encoderValue.length} elements');
            if (encoderValue.isNotEmpty) {
              _addLog('  First value: ${encoderValue[0]}');
              _addLog('  Last value: ${encoderValue[encoderValue.length - 1]}');
            }

            // Shape information - BLIP vision encoder output is [1, 577, 768]
            _addLog('  Assuming BLIP shape: [1, 577, 768]');
            if (encoderValue.length == 1 * 577 * 768) {
              _addLog('  ✓ Output length matches expected shape!');
            } else {
              _addLog('  ⚠ Output length: ${encoderValue.length}, expected: ${1 * 577 * 768}');
            }
          } else {
            _addLog('  Output value is not a List: $encoderValue');
          }
        } catch (e) {
          _addLog('  Could not access output value: $e');
          _addLog('  Error type: ${e.runtimeType}');
        }

        // Clean up
        inputTensor.release();
        runOptions.release();
        for (final output in outputs) {
          output?.release();
        }
        _addLog('✓ Resources cleaned up');

      } catch (e, stackTrace) {
        _addLog('✗ ERROR in vision encoder inference: $e');
        _addLog('  Error type: ${e.runtimeType}');
        _addLog('  Stack trace: ${stackTrace.toString().substring(0, 200)}...');
        inputTensor?.release();
        return;
      }

      // Step 7: Test tokenizer
      _addLog('\n[Step 7] Testing tokenizer...');
      try {
        await TokenizerService.initialize();
        _addLog('✓ Tokenizer initialized');

        final testTokens = [TokenizerService.getClsTokenId(), 100, 200, TokenizerService.getSepTokenId()];
        final decoded = TokenizerService.decodeTokens(testTokens);
        _addLog('  Test decode: $decoded');
      } catch (e) {
        _addLog('✗ Tokenizer error: $e');
      }

      // Cleanup
      _addLog('\n[Cleanup] Releasing resources...');
      visionSession.release();
      decoderSession.release();
      visionSessionOptions.release();
      decoderSessionOptions.release();
      _addLog('✓ All resources released');

      _addLog('\n' + '=' * 60);
      _addLog('Test completed successfully!');
      _addLog('=' * 60);

    } catch (e, stackTrace) {
      _addLog('\n✗ FATAL ERROR: $e');
      _addLog('  Error type: ${e.runtimeType}');
      final stackStr = stackTrace.toString();
      final maxLen = stackStr.length > 300 ? 300 : stackStr.length;
      _addLog('  Stack trace: ${stackStr.substring(0, maxLen)}${stackStr.length > 300 ? "..." : ""}');
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ONNX Inference Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: _isRunning ? null : _runTest,
            tooltip: 'Run Test',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _logs.clear();
              });
            },
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isRunning)
            const LinearProgressIndicator(),
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'Tap the play button to run the test',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      final isError = log.contains('✗') ||
                          log.contains('ERROR');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: isError ? Colors.red : Colors.black87,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

