import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:ceriv_app/models/presence.dart';
import 'package:ceriv_app/repositories/presence_repository.dart';
import 'package:ceriv_app/services/service_locator.dart';
import 'package:ceriv_app/services/offline_queue_service.dart';

part 'presence_event.dart';
part 'presence_state.dart';

class PresenceBloc extends Bloc<PresenceEvent, PresenceState> {
  final PresenceRepository _presenceRepository = getIt<PresenceRepository>();
  final OfflineQueueService _offlineQueueService = getIt<OfflineQueueService>();

  PresenceBloc() : super(PresenceInitial()) {
    on<LoadPresencesEvent>(_onLoadPresences);
    on<RegisterPresenceEvent>(_onRegisterPresence);
  }

  Future<void> _onLoadPresences(
    LoadPresencesEvent event,
    Emitter<PresenceState> emit,
  ) async {
    try {
      emit(PresenceLoading());

      // Buscar presenças
      final response = await _presenceRepository.getPresences(
        limit: event.limit,
        offset: event.offset,
      );

      if (response.isSuccess && response.dataList != null) {
        // Presenças carregadas com sucesso
        emit(PresencesLoaded(presences: response.dataList!));
      } else {
        // Erro ao carregar presenças
        emit(PresenceError(
          message: response.error?.message ?? 'Erro ao carregar presenças',
        ));
      }
    } catch (e) {
      debugPrint('Erro ao carregar presenças: $e');
      emit(PresenceError(message: 'Erro ao carregar presenças: $e'));
    }
  }

  Future<void> _onRegisterPresence(
    RegisterPresenceEvent event,
    Emitter<PresenceState> emit,
  ) async {
    try {
      emit(PresenceLoading());

      if (event.isOffline) {
        // Adicionar operação à fila offline
        final operation = OfflineOperation(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: OperationType.post,
          endpoint: '/api/presences/qr',
          data: {
            'qr_code': event.qrCode,
            'latitude': event.latitude,
            'longitude': event.longitude,
          },
          isCritical: true, // Presença é uma operação crítica
        );

        await _offlineQueueService.addOperation(operation);

        // Emitir estado de sucesso (será sincronizado quando houver conexão)
        emit(const PresenceRegistered(
          message: 'Presença registrada em modo offline. Será sincronizada quando houver conexão.',
          isOffline: true,
        ));
      } else {
        // Registrar presença online
        final response = await _presenceRepository.registerPresence(
          qrCode: event.qrCode,
          latitude: event.latitude,
          longitude: event.longitude,
        );

        if (response.isSuccess) {
          // Presença registrada com sucesso
          emit(PresenceRegistered(
            message: response.message ?? 'Presença registrada com sucesso',
            isOffline: false,
          ));
          
          // Recarregar lista de presenças
          add(const LoadPresencesEvent());
        } else {
          // Erro ao registrar presença
          emit(PresenceError(
            message: response.error?.message ?? 'Erro ao registrar presença',
          ));
        }
      }
    } catch (e) {
      debugPrint('Erro ao registrar presença: $e');
      emit(PresenceError(message: 'Erro ao registrar presença: $e'));
    }
  }
}