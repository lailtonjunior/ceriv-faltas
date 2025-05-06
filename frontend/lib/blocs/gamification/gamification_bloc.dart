import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:ceriv_app/models/badge.dart';
import 'package:ceriv_app/repositories/badge_repository.dart';
import 'package:ceriv_app/services/service_locator.dart';

part 'gamification_event.dart';
part 'gamification_state.dart';

class GamificationBloc extends Bloc<GamificationEvent, GamificationState> {
  final BadgeRepository _badgeRepository = getIt<BadgeRepository>();

  GamificationBloc() : super(GamificationInitial()) {
    on<LoadBadgesEvent>(_onLoadBadges);
    on<LoadBadgeDetailsEvent>(_onLoadBadgeDetails);
    on<LoadRankingEvent>(_onLoadRanking);
  }

  Future<void> _onLoadBadges(
    LoadBadgesEvent event,
    Emitter<GamificationState> emit,
  ) async {
    try {
      emit(GamificationLoading());

      // Buscar badges
      final response = await _badgeRepository.getBadges();

      if (response.isSuccess && response.dataList != null) {
        // Calcular pontuação total
        final totalPoints = response.dataList!.fold<int>(
          0,
          (sum, badge) => sum + badge.points,
        );

        // Badges carregados com sucesso
        emit(BadgesLoaded(
          badges: response.dataList!,
          totalPoints: totalPoints,
        ));
      } else {
        // Erro ao carregar badges
        emit(GamificationError(
          message: response.error?.message ?? 'Erro ao carregar conquistas',
        ));
      }
    } catch (e) {
      debugPrint('Erro ao carregar badges: $e');
      emit(GamificationError(message: 'Erro ao carregar conquistas: $e'));
    }
  }

  Future<void> _onLoadBadgeDetails(
    LoadBadgeDetailsEvent event,
    Emitter<GamificationState> emit,
  ) async {
    try {
      emit(GamificationLoading());

      // Buscar detalhes do badge
      final response = await _badgeRepository.getBadgeDetails(event.badgeId);

      if (response.isSuccess && response.data != null) {
        // Badge carregado com sucesso
        emit(BadgeDetailsLoaded(badge: response.data!));
      } else {
        // Erro ao carregar badge
        emit(GamificationError(
          message: response.error?.message ?? 'Erro ao carregar detalhes da conquista',
        ));
      }
    } catch (e) {
      debugPrint('Erro ao carregar detalhes do badge: $e');
      emit(GamificationError(message: 'Erro ao carregar detalhes da conquista: $e'));
    }
  }

  Future<void> _onLoadRanking(
    LoadRankingEvent event,
    Emitter<GamificationState> emit,
  ) async {
    try {
      emit(GamificationLoading());

      // Buscar ranking
      final response = await _badgeRepository.getRanking(event.limit);

      if (response.isSuccess && response.data != null) {
        // Ranking carregado com sucesso
        emit(RankingLoaded(ranking: response.data!));
      } else {
        // Erro ao carregar ranking
        emit(GamificationError(
          message: response.error?.message ?? 'Erro ao carregar ranking',
        ));
      }
    } catch (e) {
      debugPrint('Erro ao carregar ranking: $e');
      emit(GamificationError(message: 'Erro ao carregar ranking: $e'));
    }
  }
}