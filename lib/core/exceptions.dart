/// Custom exceptions for the app
abstract class AppException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  AppException(this.message, [this.stackTrace]);

  @override
  String toString() => message;
}

/// Exception for image processing errors
class ImageProcessingException extends AppException {
  ImageProcessingException(super.message, [super.stackTrace]);
}

/// Exception for ONNX model inference errors
class OnnxException extends AppException {
  OnnxException(super.message, [super.stackTrace]);
}

/// Exception for database/repository operations
class RepositoryException extends AppException {
  RepositoryException(super.message, [super.stackTrace]);
}

/// Exception for permission-related errors
class PermissionException extends AppException {
  PermissionException(super.message, [super.stackTrace]);
}

/// Exception for tokenizer operations
class TokenizerException extends AppException {
  TokenizerException(super.message, [super.stackTrace]);
}
