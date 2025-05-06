part of 'gamification_bloc.dart';

abstract class GamificationState extends Equatable {
  const GamificationState();
  
  @override
  List<Object?> get props => [];
}

class GamificationInitial extends GamificationState {}

class GamificationLoading extends GamificationState {}

class BadgesLoaded extends GamificationState {
  final List<Badge> badges;
  final int totalPoints;

  const BadgesLoaded({
    required this.badges,
    required this.totalPoints,
  });

  @override
  List<Object?> get props => [badges, totalPoints];
}

class BadgeDetailsLoaded extends GamificationState {
  final Badge badge;

  const BadgeDetailsLoaded({
    required this.badge,
  });

  @override
  List<Object?> get props => [badge];
}

class RankingLoaded extends GamificationState {
  final List<Map<String, dynamic>> ranking;

  const RankingLoaded({
    required this.ranking,
  });

  @override
  List<Object?> get props => [ranking];
}

class GamificationError extends GamificationState {
  final String message;

  const GamificationError({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}