class ApiError {
  final String message;
  final int statusCode;
  final dynamic rawError;
  final Map<String, dynamic>? data;

  ApiError({
    required this.message,
    required this.statusCode,
    this.rawError,
    this.data,
  });

  @override
  String toString() {
    return 'ApiError(message: $message, statusCode: $statusCode)';
  }

  // Helpers para verificar o tipo de erro
  bool get isNetworkError => statusCode == 0 || statusCode >= 500;
  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isNotFoundError => statusCode == 404;
  bool get isValidationError => statusCode == 422;
  bool get isServerError => statusCode >= 500;
  bool get isClientError => statusCode >= 400 && statusCode < 500;
}