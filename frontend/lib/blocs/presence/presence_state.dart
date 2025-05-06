part of 'presence_bloc.dart';

abstract class PresenceState extends Equatable {
  const PresenceState();
  
  @override
  List<Object?> get props => [];
}

class PresenceInitial extends PresenceState {}

class PresenceLoading extends PresenceState {}

class PresencesLoaded extends PresenceState {
  final List<Presence> presences;

  const PresencesLoaded({
    required this.presences,
  });

  @override
  List<Object?> get props => [presences];
}

class PresenceRegistered extends PresenceState {
  final String message;
  final bool isOffline;

  const PresenceRegistered({
    required this.message,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [message, isOffline];
}

class PresenceError extends PresenceState {
  final String message;

  const PresenceError({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}

class PresenceStatsLoaded extends PresenceState {
  final Map<String, dynamic> stats;

  const PresenceStatsLoaded({
    required this.stats,
  });

  @override
  List<Object?> get props => [stats];
}

class AbsenceJustified extends PresenceState {
  final String message;

  const AbsenceJustified({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}