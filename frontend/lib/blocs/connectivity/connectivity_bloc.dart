import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:ceriv_app/services/service_locator.dart';
import 'package:ceriv_app/services/offline_queue_service.dart';

part 'connectivity_event.dart';
part 'connectivity_state.dart';

class ConnectivityBloc extends Bloc<ConnectivityEvent, ConnectivityState> {
  final Connectivity _connectivity;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  final OfflineQueueService _offlineQueueService = getIt<OfflineQueueService>();

  ConnectivityBloc(this._connectivity) : super(ConnectivityInitial()) {
    on<ConnectivityStartMonitoring>(_onStartMonitoring);
    on<ConnectivityStatusChanged>(_onStatusChanged);
    on<ConnectivityStopMonitoring>(_onStopMonitoring);
    
    // Iniciar monitoramento automaticamente
    add(ConnectivityStartMonitoring());
  }

  Future<void> _onStartMonitoring(
    ConnectivityStartMonitoring event,
    Emitter<ConnectivityState> emit,
  ) async {
    try {
      // Verificar status inicial de conectividade
      final connectivityResult = await _connectivity.checkConnectivity();
      
      // Emitir estado inicial
      if (connectivityResult == ConnectivityResult.none) {
        emit(ConnectivityOffline());
      } else {
        emit(ConnectivityOnline());
      }
      
      // Configurar listener para mudanças de conectividade
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
        add(ConnectivityStatusChanged(result));
      });
    } catch (e) {
      debugPrint('Erro ao iniciar monitoramento de conectividade: $e');
      emit(ConnectivityError(message: 'Erro ao monitorar conectividade: $e'));
    }
  }

  Future<void> _onStatusChanged(
    ConnectivityStatusChanged event,
    Emitter<ConnectivityState> emit,
  ) async {
    try {
      if (event.result == ConnectivityResult.none) {
        // Dispositivo offline
        emit(ConnectivityOffline());
      } else {
        // Dispositivo online
        emit(ConnectivityOnline());
        
        // Tentar sincronizar fila offline
        if (!_offlineQueueService.isQueueEmpty) {
          debugPrint('Conectividade restaurada, sincronizando operações offline...');
          _offlineQueueService.syncQueue();
        }
      }
    } catch (e) {
      debugPrint('Erro ao processar mudança de conectividade: $e');
      emit(ConnectivityError(message: 'Erro ao processar mudança de conectividade: $e'));
    }
  }

  Future<void> _onStopMonitoring(
    ConnectivityStopMonitoring event,
    Emitter<ConnectivityState> emit,
  ) async {
    await _connectivitySubscription.cancel();
  }

  @override
  Future<void> close() {
    _connectivitySubscription.cancel();
    return super.close();
  }
}