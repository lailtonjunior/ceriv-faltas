import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ceriv_app/models/offline_operation.dart';
import 'package:ceriv_app/services/api_service.dart';
import 'package:ceriv_app/services/service_locator.dart';
import 'package:ceriv_app/services/storage_service.dart';

/// Serviço para gerenciar a fila de operações offline e sincronização
class OfflineQueueService {
  final StorageService _storageService = getIt<StorageService>();
  final ApiService _apiService = getIt<ApiService>();
  
  bool _isSyncing = false;
  Timer? _syncTimer;
  final List<Function(bool)> _syncCompletionCallbacks = [];
  
  // Número máximo de tentativas para uma operação
  static const int maxAttempts = 5;
  
  // Intervalo entre tentativas automáticas de sincronização
  static const Duration syncInterval = Duration(minutes: 5);
  
  /// Inicializa o serviço, configurando sincronização periódica
  void init() {
    // Configurar timer para sincronização periódica
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(syncInterval, (_) => synchronize());
  }
  
  /// Libera recursos quando o serviço for desativado
  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  /// Adiciona uma operação à fila offline
  Future<void> addOperation(OfflineOperation operation) async {
    await _storageService.addOfflineOperation(operation);
  }
  
  /// Obtém todas as operações pendentes
  Future<List<OfflineOperation>> getOperations() async {
    return await _storageService.getOfflineOperations();
  }
  
  /// Inicia processo de sincronização das operações pendentes
  Future<bool> synchronize({
    Function(bool)? onComplete,
  }) async {
    // Se já estiver sincronizando, registrar callback e retornar
    if (_isSyncing) {
      if (onComplete != null) {
        _syncCompletionCallbacks.add(onComplete);
      }
      return false;
    }
    
    _isSyncing = true;
    bool success = false;
    
    try {
      if (onComplete != null) {
        _syncCompletionCallbacks.add(onComplete);
      }
      
      // Obter operações pendentes
      final operations = await getOperations();
      
      if (operations.isEmpty) {
        _isSyncing = false;
        _notifyCompletionCallbacks(true);
        return true;
      }
      
      // Ordenar por prioridade (menor número = maior prioridade)
      operations.sort((a, b) => a.priority.compareTo(b.priority));
      
      for (final operation in operations) {
        if (operation.attempts >= maxAttempts) {
          // Operação excedeu o número máximo de tentativas, remover
          await _storageService.removeOfflineOperation(operation.id);
          continue;
        }
        
        try {
          final response = await _executeOperation(operation);
          if (response.statusCode >= 200 && response.statusCode < 300) {
            // Sucesso, remover operação da fila
            await _storageService.removeOfflineOperation(operation.id);
          } else {
            // Falha, incrementar tentativas
            final updatedOperation = operation.incrementAttempts();
            await _storageService.removeOfflineOperation(operation.id);
            await _storageService.addOfflineOperation(updatedOperation);
          }
        } catch (e) {
          // Erro, incrementar tentativas
          final updatedOperation = operation.incrementAttempts();
          await _storageService.removeOfflineOperation(operation.id);
          await _storageService.addOfflineOperation(updatedOperation);
        }
      }
      
      // Verificar se todas as operações foram processadas
      final remainingOperations = await getOperations();
      success = remainingOperations.isEmpty;
    } catch (e) {
      debugPrint('Erro durante sincronização: $e');
      success = false;
    } finally {
      _isSyncing = false;
      _notifyCompletionCallbacks(success);
    }
    
    return success;
  }
  
  /// Executa uma operação específica usando o ApiService
  Future<dynamic> _executeOperation(OfflineOperation operation) async {
    switch (operation.method.toUpperCase()) {
      case 'GET':
        return await _apiService.get(operation.endpoint);
      case 'POST':
        return await _apiService.post(operation.endpoint, operation.data);
      case 'PUT':
        return await _apiService.put(operation.endpoint, operation.data);
      case 'PATCH':
        return await _apiService.patch(operation.endpoint, operation.data);
      case 'DELETE':
        return await _apiService.delete(operation.endpoint);
      default:
        throw Exception('Método HTTP não suportado: ${operation.method}');
    }
  }
  
  /// Limpa todas as operações pendentes
  Future<void> clearOperations() async {
    await _storageService.clearOfflineOperations();
  }
  
  /// Notifica os callbacks registrados sobre a conclusão da sincronização
  void _notifyCompletionCallbacks(bool success) {
    for (final callback in _syncCompletionCallbacks) {
      callback(success);
    }
    _syncCompletionCallbacks.clear();
  }
}