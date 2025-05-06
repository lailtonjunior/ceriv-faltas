import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ceriv_app/models/api_response.dart';
import 'package:ceriv_app/models/api_error.dart';
import 'package:ceriv_app/models/presence.dart';
import 'package:ceriv_app/models/offline_operation.dart';
import 'package:ceriv_app/services/api_service.dart';
import 'package:ceriv_app/services/service_locator.dart';
import 'package:ceriv_app/services/storage_service.dart';
import 'package:ceriv_app/services/offline_queue_service.dart';

/// Repositório para gerenciar operações relacionadas a presenças
class PresenceRepository {
  final ApiService _apiService = getIt<ApiService>();
  final StorageService _storageService = getIt<StorageService>();
  final OfflineQueueService _offlineQueueService = getIt<OfflineQueueService>();
  final SupabaseClient _supabaseClient = getIt<SupabaseClient>();
  
  /// Registra uma presença através de QR Code
  Future<ApiResponse<bool>> registerPresence({
    required String scheduleId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final data = {
        'schedule_id': scheduleId,
        'latitude': latitude,
        'longitude': longitude,
        'check_in_time': DateTime.now().toIso8601String(),
      };
      
      // Tentar enviar via API
      final response = await _apiService.post('/presences', data);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(true);
      }
      
      // Se falhar, tentar via Supabase
      try {
        await _supabaseClient.from('presences').insert(data);
        return ApiResponse.success(true);
      } catch (supabaseError) {
        // Se também falhar, salvar para sincronização posterior
        final operation = OfflineOperation.create(
          type: OperationType.create,
          endpoint: '/presences',
          data: data,
          method: 'POST',
          priority: 2, // Alta prioridade
          entityType: 'presence',
        );
        
        await _offlineQueueService.addOperation(operation);
        
        return ApiResponse.success(true);
      }
    } on SocketException {
      // Sem conexão, salvar para sincronização posterior
      final operation = OfflineOperation.create(
        type: OperationType.create,
        endpoint: '/presences',
        data: {
          'schedule_id': scheduleId,
          'latitude': latitude,
          'longitude': longitude,
          'check_in_time': DateTime.now().toIso8601String(),
        },
        method: 'POST',
        priority: 2, // Alta prioridade
        entityType: 'presence',
      );
      
      await _offlineQueueService.addOperation(operation);
      
      return ApiResponse.success(true);
    } catch (e) {
      debugPrint('Erro ao registrar presença: $e');
      return ApiResponse.error(
        ApiError(
          code: 'UNKNOWN',
          message: 'Erro ao registrar presença. Tente novamente.',
        ),
      );
    }
  }
  
  /// Obtém o histórico de presenças
  Future<ApiResponse<List<Presence>>> getPresenceHistory() async {
    try {
      final response = await _apiService.get('/presences/history');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        final presences = data.map((json) => Presence.fromJson(json)).toList();
        
        // Salvar localmente para acesso offline
        await _savePresencesLocally(presences);
        
        return ApiResponse.success(presences);
      } else {
        // Tentar obter via Supabase
        try {
          final userId = _supabaseClient.auth.currentUser?.id;
          
          if (userId == null) {
            throw Exception('Usuário não autenticado');
          }
          
          final data = await _supabaseClient
              .from('presences')
              .select('*, schedules(*)')
              .eq('patient_id', userId)
              .order('check_in_time', ascending: false);
              
          if (data != null) {
            final presences = (data as List).map((json) => Presence.fromJson(json)).toList();
            
            // Salvar localmente
            await _savePresencesLocally(presences);
            
            return ApiResponse.success(presences);
          }
        } catch (supabaseError) {
          debugPrint('Erro ao obter presenças do Supabase: $supabaseError');
        }
        
        // Tentar obter do armazenamento local
        return await _getLocalPresences();
      }
    } on SocketException {
      // Sem conexão, usar cache local
      return await _getLocalPresences();
    } catch (e) {
      debugPrint('Erro ao obter histórico de presenças: $e');
      
      // Última tentativa: armazenamento local
      final localResponse = await _getLocalPresences();
      if (localResponse.isSuccess && localResponse.data != null) {
        return localResponse;
      }
      
      return ApiResponse.error(
        ApiError(
          code: 'UNKNOWN',
          message: 'Erro ao obter histórico de presenças',
        ),
      );
    }
  }
  
  /// Justifica uma falta
  Future<ApiResponse<bool>> justifyAbsence({
    required String scheduleId,
    required String reason,
    required String? attachmentUrl,
  }) async {
    try {
      final data = {
        'schedule_id': scheduleId,
        'reason': reason,
        'attachment_url': attachmentUrl,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Tentar enviar via API
      final response = await _apiService.post('/absences/justify', data);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(true);
      }
      
      // Se falhar, tentar via Supabase
      try {
        await _supabaseClient.from('absence_justifications').insert(data);
        return ApiResponse.success(true);
      } catch (supabaseError) {
        // Se também falhar, salvar para sincronização posterior
        final operation = OfflineOperation.create(
          type: OperationType.create,
          endpoint: '/absences/justify',
          data: data,
          method: 'POST',
          priority: 3,
          entityType: 'absence_justification',
        );
        
        await _offlineQueueService.addOperation(operation);
        
        return ApiResponse.success(true);
      }
    } on SocketException {
      // Sem conexão, salvar para sincronização posterior
      final operation = OfflineOperation.create(
        type: OperationType.create,
        endpoint: '/absences/justify',
        data: {
          'schedule_id': scheduleId,
          'reason': reason,
          'attachment_url': attachmentUrl,
          'created_at': DateTime.now().toIso8601String(),
        },
        method: 'POST',
        priority: 3,
        entityType: 'absence_justification',
      );
      
      await _offlineQueueService.addOperation(operation);
      
      return ApiResponse.success(true);
    } catch (e) {
      debugPrint('Erro ao justificar falta: $e');
      return ApiResponse.error(
        ApiError(
          code: 'UNKNOWN',
          message: 'Erro ao justificar falta. Tente novamente.',
        ),
      );
    }
  }
  
  /// Obtém estatísticas de presenças (contagens, percentuais)
  Future<ApiResponse<Map<String, dynamic>>> getPresenceStatistics() async {
    try {
      final response = await _apiService.get('/presences/statistics');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> statistics = response.data['data'] ?? {};
        return ApiResponse.success(statistics);
      } else {
        // Cálculo local de estatísticas
        final presenceHistory = await getPresenceHistory();
        
        if (presenceHistory.isSuccess && presenceHistory.data != null) {
          final statistics = _calculateLocalStatistics(presenceHistory.data!);
          return ApiResponse.success(statistics);
        }
        
        return ApiResponse.error(
          ApiError(
            code: response.statusCode.toString(),
            message: response.data['message'] ?? 'Erro ao obter estatísticas',
          ),
        );
      }
    } on SocketException {
      // Cálculo local de estatísticas
      final presenceHistory = await getPresenceHistory();
      
      if (presenceHistory.isSuccess && presenceHistory.data != null) {
        final statistics = _calculateLocalStatistics(presenceHistory.data!);
        return ApiResponse.success(statistics);
      }
      
      return ApiResponse.error(
        ApiError(
          code: 'NO_CONNECTION',
          message: 'Sem conexão com a internet',
        ),
      );
    } catch (e) {
      debugPrint('Erro ao obter estatísticas de presenças: $e');
      
      // Tentativa local como fallback
      try {
        final presenceHistory = await getPresenceHistory();
        
        if (presenceHistory.isSuccess && presenceHistory.data != null) {
          final statistics = _calculateLocalStatistics(presenceHistory.data!);
          return ApiResponse.success(statistics);
        }
      } catch (_) {}
      
      return ApiResponse.error(
        ApiError(
          code: 'UNKNOWN',
          message: 'Erro ao obter estatísticas de presenças',
        ),
      );
    }
  }
  
  /// Métodos privados para manipulação local
  
  /// Salva presenças localmente
  Future<void> _savePresencesLocally(List<Presence> presences) async {
    final List<Map<String, dynamic>> presencesList = presences.map((p) => p.toJson()).toList();
    await _storageService.setStringValue('cached_presences', presencesList.toString());
  }
  
  /// Obtém presenças do armazenamento local
  Future<ApiResponse<List<Presence>>> _getLocalPresences() async {
    try {
      final String? presencesJson = await _storageService.getStringValue('cached_presences');
      
      if (presencesJson == null || presencesJson.isEmpty) {
        return ApiResponse.error(
          ApiError(
            code: 'NO_LOCAL_DATA',
            message: 'Nenhum dado de presença disponível localmente',
          ),
        );
      }
      
      final List<dynamic> presencesList = presencesJson as List<dynamic>;
      final presences = presencesList.map((json) => Presence.fromJson(json)).toList();
      
      return ApiResponse.success(presences);
    } catch (e) {
      return ApiResponse.error(
        ApiError(
          code: 'LOCAL_ERROR',
          message: 'Erro ao obter presenças localmente',
        ),
      );
    }
  }
  
  /// Calcula estatísticas localmente
  Map<String, dynamic> _calculateLocalStatistics(List<Presence> presences) {
    final totalSessions = presences.length;
    final presentCount = presences.where((p) => p.status == 'present').length;
    final absentCount = presences.where((p) => p.status == 'absent').length;
    final justifiedCount = presences.where((p) => p.status == 'justified').length;
    
    final presentPercentage = totalSessions > 0 ? (presentCount / totalSessions) * 100 : 0;
    final absentPercentage = totalSessions > 0 ? (absentCount / totalSessions) * 100 : 0;
    final justifiedPercentage = totalSessions > 0 ? (justifiedCount / totalSessions) * 100 : 0;
    
    return {
      'total_sessions': totalSessions,
      'present_count': presentCount,
      'absent_count': absentCount,
      'justified_count': justifiedCount,
      'present_percentage': presentPercentage,
      'absent_percentage': absentPercentage,
      'justified_percentage': justifiedPercentage,
    };
  }
}