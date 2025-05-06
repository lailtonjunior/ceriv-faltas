import 'package:ceriv_app/models/api_error.dart';

class ApiResponse<T> {
  final T? data;
  final List<T>? dataList;
  final dynamic rawData;
  final ApiError? error;
  final int statusCode;
  final String? message;
  final bool isFromCache;

  ApiResponse({
    this.data,
    this.dataList,
    this.rawData,
    this.error,
    required this.statusCode,
    this.message,
    this.isFromCache = false,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300 && error == null;
  bool get isError => !isSuccess;
  bool get hasData => data != null || dataList != null || rawData != null;

  @override
  String toString() {
    return 'ApiResponse(statusCode: $statusCode, isSuccess: $isSuccess, message: $message)';
  }
}