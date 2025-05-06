part of 'gamification_bloc.dart';

abstract class GamificationEvent extends Equatable {
  const GamificationEvent();

  @override
  List<Object?> get props => [];
}

class LoadBadgesEvent extends GamificationEvent {
  const LoadBadgesEvent();
}

class LoadBadgeDetailsEvent extends GamificationEvent {
  final int badgeId;

  const LoadBadgeDetailsEvent({
    required this.badgeId,
  });

  @override
  List<Object?> get props => [badgeId];
}

class LoadRankingEvent extends GamificationEvent {
  final int limit;

  const LoadRankingEvent({
    this.limit = 10,
  });

  @override
  List<Object?> get props => [limit];
}