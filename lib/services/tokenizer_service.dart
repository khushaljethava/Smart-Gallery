import 'package:flutter/services.dart';

/// Service for tokenizing text and decoding token IDs to text.
/// Used for BLIP model caption generation.
class TokenizerService {
  static const int clsTokenId = 101; // [CLS] token
  static const int sepTokenId = 102; // [SEP] token
  static const int padTokenId = 0;
  static const int vocabSize = 30524;

  static List<String>? _vocabulary;
  static Map<String, int>? _wordToId;
  static bool _isInitialized = false;

  /// Initialize the tokenizer by loading vocabulary
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('TokenizerService: Already initialized');
      return;
    }

    try {
      print('TokenizerService: Initializing tokenizer...');
      await _loadVocabulary();
      _isInitialized = true;
      print('TokenizerService: Initialization complete');
    } catch (e) {
      print('TokenizerService: Error initializing: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  /// Load vocabulary from assets
  static Future<void> _loadVocabulary() async {
    try {
      print('TokenizerService: Loading vocabulary from models/blip_processor/vocab.txt');

      final vocabText = await rootBundle.loadString('models/blip_processor/vocab.txt');
      _vocabulary =
          vocabText.split('\n').map((line) => line.trim()).toList();

      // Create reverse mapping for encoding
      _wordToId = {};
      for (int i = 0; i < _vocabulary!.length; i++) {
        _wordToId![_vocabulary![i]] = i;
      }

      print(
          'TokenizerService: Loaded vocabulary with ${_vocabulary!.length} tokens');
    } catch (e) {
      print('TokenizerService: Error loading vocabulary: $e');
      print(
          'TokenizerService: Vocabulary file not found at models/blip_processor/vocab.txt');
      print(
          'TokenizerService: Please ensure vocab.txt is in the models/blip_processor/ directory');
      rethrow;
    }
  }

  /// Decode token IDs to human-readable text
  ///
  /// This method converts token IDs output by the BLIP text decoder into
  /// readable English text by looking up each token ID in the vocabulary.
  /// Special tokens and padding are automatically handled.
  static String decodeTokens(List<int> tokenIds) {
    if (_vocabulary == null) {
      throw StateError(
          'Tokenizer not initialized. Call TokenizerService.initialize() first.');
    }

    final words = <String>[];

    for (final tokenId in tokenIds) {
      // Validate token ID is in range
      if (tokenId >= 0 && tokenId < _vocabulary!.length) {
        final token = _vocabulary![tokenId];
        if (token.isNotEmpty && 
            !token.startsWith('[') && 
            token != '[PAD]' && 
            token != '[UNK]' && 
            token != '[MASK]') {
          words.add(token);
        }
      }
    }

    if (words.isEmpty) {
      return '';
    }

    String text = words[0];
    for (int i = 1; i < words.length; i++) {
      final token = words[i];
      if (token.startsWith('##')) {
        text += token.substring(2);
      } else {
        text += ' $token';
      }
    }
    
    final finalCaption = text.trim();
    print('TokenizerService: Decoded caption: "$finalCaption"');
    return finalCaption;
  }

  /// Encode text to token IDs (basic implementation)
  ///
  /// This is a simplified version that does word-level tokenization.
  /// For production, you may need more sophisticated subword tokenization.
  static List<int> encodeTokens(String text) {
    if (_wordToId == null) {
      throw StateError(
          'Tokenizer not initialized. Call TokenizerService.initialize() first.');
    }

    final tokens = <int>[clsTokenId]; // Start with [CLS]

    final words = text.toLowerCase().split(' ');
    for (final word in words) {
      // Try exact match first
      if (_wordToId!.containsKey(word)) {
        tokens.add(_wordToId![word]!);
      } else {
        // Use [UNK] token for unknown words
        tokens.add(_wordToId!['[UNK]'] ?? 100);
      }
    }

    tokens.add(sepTokenId); // End with [SEP]
    return tokens;
  }

  /// Get the vocabulary list (for debugging)
  static List<String>? getVocabulary() => _vocabulary;

  /// Get vocabulary size
  static int getVocabSize() => vocabSize;

  /// Get CLS token ID
  static int getClsTokenId() => clsTokenId;

  /// Get SEP token ID
  static int getSepTokenId() => sepTokenId;

  /// Check if tokenizer is initialized
  static bool get isInitialized => _isInitialized;

  /// Dispose resources
  static void dispose() {
    _vocabulary = null;
    _wordToId = null;
    _isInitialized = false;
    print('TokenizerService: Disposed');
  }
}
