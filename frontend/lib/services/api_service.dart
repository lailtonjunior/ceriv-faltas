import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ceriv_app/services/auth_service.dart';
import 'package:ceriv_app/services/storage_service.dart';
import 'package:ceriv_app/services/service_locator.dart';
import 'package:ceriv_app/models/api_response.dart';
import 'package:ceriv_app/models/api_error.dart';

/// Serviço para comunicação com a API.
class ApiService {
  late Dio _dio;
  late String _baseUrl;
  final AuthService _authService = getIt<AuthService>();
  final StorageService _storageService = getIt<StorageService>();
  
  ApiService() {
    _initialize();
  }
  
  /// Inicializa o serviço de API.
  void _initialize() {
    // Obter URL base da API do arquivo .env
    _baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000';
    
    // Configurar Dio
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    
    // Adicionar interceptor para token de autenticação
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Verificar conectividade
          final connectivityResult = await Connectivity().checkConnectivity();
          if (connectivityResult == ConnectivityResult.none) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Sem conexão com a internet',
                type: DioExceptionType.connectionError,
              ),
            );
          }
          
          // Adicionar token de autenticação, se disponível
          final token = await _authService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          return handler.next(options);
        },
        onError: (error, handler) async {
          // Tratar erros de autenticação
          if (error.response?.statusCode == 401) {
            // Token expirado ou inválido
            try {
              final refreshed = await _authService.refreshToken();
              if (refreshed) {
                // Repetir a requisição com o novo token
                final token = await _authService.getToken();
                error.requestOptions.headers['Authorization'] = 'Bearer $token';
                
                // Criar nova requisição com o token atualizado
                final response = await _dio.fetch(error.requestOptions);
                return handler.resolve(response);
              }
            } catch (e) {
              debugPrint('Erro ao atualizar token: $e');
            }
            
            // Falha ao atualizar token, deslogar usuário
            await _authService.logout();
          }
          
          return handler.next(error);
        },
      ),
    );
  }
  
  /// Realiza uma requisição GET.
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
    List<T> Function(List<dynamic>)? fromJsonList,
    bool useCache = false,
    Duration cacheDuration = const Duration(minutes: 5),
  }) async {
    try {
      // Verificar cache, se solicitado
      if (useCache) {
        final cacheKey = '${endpoint}_${queryParameters.toString()}';
        final cachedData = await _storageService.getCache(cacheKey);
        
        if (cachedData != null) {
          final cacheTime = await _storageService.getCacheTime(cacheKey);
          final now = DateTime.now();
          
          // Verificar se o cache ainda é válido
          if (cacheTime != null && now.difference(cacheTime) < cacheDuration) {
            // Converter dados do cache
            if (fromJson != null && cachedData is Map<String, dynamic>) {
              return ApiResponse(
                data: fromJson(cachedData),
                statusCode: 200,
                isFromCache: true,
              );
            } else if (fromJsonList != null && cachedData is List) {
              return ApiResponse(
                dataList: fromJsonList(cachedData),
                statusCode: 200,
                isFromCache: true,
              );
            }
          }
        }
      }
      
      // Realizar requisição
      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      
      // Processar resposta
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Converter dados
        if (fromJson != null && response.data is Map<String, dynamic>) {
          return ApiResponse(
            data: fromJson(response.data),
            statusCode: response.statusCode,
          );
        } else {
          return ApiResponse(
            rawData: response.data,
            statusCode: response.statusCode,
          );
        }
      } else {
        throw ApiError(
          message: 'Erro na requisição: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(
        error: ApiError(
          message: 'Erro inesperado: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Manipula erros do Dio.
  ApiResponse<T> _handleDioError<T>(DioException e) {
    // Determinar código de status
    int statusCode = e.response?.statusCode ?? 500;
    
    // Criar mensagem de erro
    String errorMessage;
    
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        errorMessage = 'Tempo de conexão esgotado. Verifique sua conexão e tente novamente.';
        break;
      case DioExceptionType.connectionError:
        errorMessage = 'Sem conexão com a internet. Verifique sua conexão e tente novamente.';
        break;
      case DioExceptionType.badResponse:
        // Tentar extrair mensagem de erro da resposta
        if (e.response?.data is Map<String, dynamic>) {
          errorMessage = e.response?.data['detail'] ?? 
                        e.response?.data['message'] ?? 
                        'Erro na resposta do servidor.';
        } else if (e.response?.data is String) {
          errorMessage = e.response?.data as String;
        } else {
          errorMessage = 'Erro na resposta do servidor: ${e.response?.statusCode}';
        }
        break;
      case DioExceptionType.cancel:
        errorMessage = 'A requisição foi cancelada.';
        break;
      case DioExceptionType.unknown:
      default:
        if (e.error is SocketException) {
          errorMessage = 'Sem conexão com a internet. Verifique sua conexão e tente novamente.';
        } else {
          errorMessage = 'Ocorreu um erro inesperado: ${e.message}';
        }
        break;
    }
    
    return ApiResponse(
      error: ApiError(
        message: errorMessage,
        statusCode: statusCode,
        rawError: e,
      ),
      statusCode: statusCode,
    );
  }
  
  /// Limpa o cache.
  Future<void> clearCache() async {
    await _storageService.clearCache();
  }
  
  /// Verifica se há conexão com a internet.
  Future<bool> hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
  
  /// Obtém a URL base da API.
  String getBaseUrl() {
    return _baseUrl;
  }
}
.get(
        endpoint,
        queryParameters: queryParameters,
      );
      
      // Processar resposta
      if (response.statusCode == 200) {
        // Salvar no cache, se solicitado
        if (useCache) {
          final cacheKey = '${endpoint}_${queryParameters.toString()}';
          await _storageService.setCache(cacheKey, response.data);
          await _storageService.setCacheTime(cacheKey, DateTime.now());
        }
        
        // Converter dados
        if (fromJson != null && response.data is Map<String, dynamic>) {
          return ApiResponse(
            data: fromJson(response.data),
            statusCode: response.statusCode,
          );
        } else if (fromJsonList != null && response.data is List) {
          return ApiResponse(
            dataList: fromJsonList(response.data),
            statusCode: response.statusCode,
          );
        } else {
          return ApiResponse(
            rawData: response.data,
            statusCode: response.statusCode,
          );
        }
      } else {
        throw ApiError(
          message: 'Erro na requisição: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(
        error: ApiError(
          message: 'Erro inesperado: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Realiza uma requisição POST.
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      // Realizar requisição
      final response = await _dio.post(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );
      
      // Processar resposta
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Converter dados
        if (fromJson != null && response.data is Map<String, dynamic>) {
          return ApiResponse(
            data: fromJson(response.data),
            statusCode: response.statusCode,
          );
        } else {
          return ApiResponse(
            rawData: response.data,
            statusCode: response.statusCode,
          );
        }
      } else {
        throw ApiError(
          message: 'Erro na requisição: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(
        error: ApiError(
          message: 'Erro inesperado: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Realiza uma requisição PUT.
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      // Realizar requisição
      final response = await _dio.put(
        endpoint,
        data: data,
        queryParameters: queryParameters,
      );
      
      // Processar resposta
      if (response.statusCode == 200) {
        // Converter dados
        if (fromJson != null && response.data is Map<String, dynamic>) {
          return ApiResponse(
            data: fromJson(response.data),
            statusCode: response.statusCode,
          );
        } else {
          return ApiResponse(
            rawData: response.data,
            statusCode: response.statusCode,
          );
        }
      } else {
        throw ApiError(
          message: 'Erro na requisição: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(
        error: ApiError(
          message: 'Erro inesperado: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Realiza uma requisição DELETE.
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      // Realizar requisição
      final response = await _dio.delete(
        endpoint,
        queryParameters: queryParameters,
      );
      
      // Processar resposta
      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse(
          statusCode: response.statusCode,
          message: 'Recurso excluído com sucesso',
        );
      } else {
        throw ApiError(
          message: 'Erro na requisição: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      return ApiResponse(
        error: ApiError(
          message: 'Erro inesperado: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Realiza upload de arquivo.
  Future<ApiResponse<T>> uploadFile<T>(
    String endpoint, {
    required File file,
    String? fileName,
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      // Preparar formulário
      final formData = FormData();
      
      // Adicionar arquivo
      formData.files.add(
        MapEntry(
          'file',
          await MultipartFile.fromFile(
            file.path,
            filename: fileName ?? file.path.split('/').last,
          ),
        ),
      );
      
      // Adicionar outros dados, se houver
      if (data != null) {
        data.forEach((key, value) {
          formData.fields.add(MapEntry(key, value.toString()));
        });
      }
      
      // Realizar requisição
      final response = await _dio