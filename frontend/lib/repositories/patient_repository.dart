import 'package:ceriv_app/models/api_response.dart';
import 'package:ceriv_app/models/patient.dart';
import 'package:ceriv_app/services/api_service.dart';
import 'package:ceriv_app/services/storage_service.dart';
import 'package:flutter/foundation.dart';

class PatientRepository {
  final ApiService _apiService;
  final StorageService _storageService;
  
  static const String _patientCacheKey = 'patient_profile';
  
  PatientRepository({
    required ApiService apiService,
    required StorageService storageService,
  }) : 
    _apiService = apiService,
    _storageService = storageService;
  
  /// Obtém os dados do paciente atual.
  Future<ApiResponse<Patient>> getCurrentPatient() async {
    try {
      // Verificar cache
      final cachedData = await _storageService.getJson(_patientCacheKey);
      if (cachedData != null) {
        return ApiResponse<Patient>(
          data: Patient.fromMap(cachedData),
          statusCode: 200,
          isFromCache: true,
        );
      }
      
      // Buscar da API
      final response = await _apiService.get<Patient>(
        '/api/patients/me',
        fromJson: (json) => Patient.fromMap(json),
      );
      
      // Salvar no cache se for bem-sucedido
      if (response.isSuccess && response.data != null) {
        await _storageService.setJson(_patientCacheKey, response.data!.toMap());
      }
      
      return response;
    } catch (e) {
      debugPrint('Erro ao obter paciente: $e');
      return ApiResponse<Patient>(
        error: ApiError(
          message: 'Erro ao obter dados do paciente: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Atualiza os dados do paciente atual.
  Future<ApiResponse<Patient>> updatePatient(Patient patient) async {
    try {
      final response = await _apiService.put<Patient>(
        '/api/patients/me',
        data: patient.toMap(),
        fromJson: (json) => Patient.fromMap(json),
      );
      
      // Atualizar cache se for bem-sucedido
      if (response.isSuccess && response.data != null) {
        await _storageService.setJson(_patientCacheKey, response.data!.toMap());
      }
      
      return response;
    } catch (e) {
      debugPrint('Erro ao atualizar paciente: $e');
      return ApiResponse<Patient>(
        error: ApiError(
          message: 'Erro ao atualizar dados do paciente: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Atualiza o token FCM para notificações push.
  Future<ApiResponse<void>> updateFcmToken(String token) async {
    try {
      final response = await _apiService.put(
        '/api/patients/fcm_token',
        data: {'fcm_token': token},
      );
      
      return response;
    } catch (e) {
      debugPrint('Erro ao atualizar token FCM: $e');
      return ApiResponse<void>(
        error: ApiError(
          message: 'Erro ao atualizar token FCM: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Obtém as estatísticas do paciente.
  Future<ApiResponse<Map<String, dynamic>>> getPatientStats() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/api/patients/me/stats',
        fromJson: (json) => json,
      );
      
      return response;
    } catch (e) {
      debugPrint('Erro ao obter estatísticas do paciente: $e');
      return ApiResponse<Map<String, dynamic>>(
        error: ApiError(
          message: 'Erro ao obter estatísticas do paciente: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Limpa o cache do paciente.
  Future<void> clearCache() async {
    await _storageService.remove(_patientCacheKey);
  }
}

// Importação necessária para o ApiError
import 'package:ceriv_app/models/api_error.dart';