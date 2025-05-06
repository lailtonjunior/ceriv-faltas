part of 'presence_bloc.dart';

abstract class PresenceEvent extends Equatable {
  const PresenceEvent();

  @override
  List<Object?> get props => [];
}

class LoadPresencesEvent extends PresenceEvent {
  final int limit;
  final int offset;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const LoadPresencesEvent({
    this.limit = 100,
    this.offset = 0,
    this.dateFrom,
    this.dateTo,
  });

  @override
  List<Object?> get props => [limit, offset, dateFrom, dateTo];
}

class RegisterPresenceEvent extends PresenceEvent {
  final String qrCode;
  final double latitude;
  final double longitude;
  final bool isOffline;

  const RegisterPresenceEvent({
    required this.qrCode,
    required this.latitude,
    required this.longitude,
    this.isOffline = false,
  });

  @override
  List<Object?> get props => [qrCode, latitude, longitude, isOffline];
}

class GetPresenceStatsEvent extends PresenceEvent {
  final String period;

  const GetPresenceStatsEvent({
    this.period = 'month',
  });

  @override
  List<Object?> get props => [period];
}

class JustifyAbsenceEvent extends PresenceEvent {
  final int absenceId;
  final String justification;
  final String? documentPath;

  const JustifyAbsenceEvent({
    required this.absenceId,
    required this.justification,
    this.documentPath,
  });

  @override
  List<Object?> get props => [absenceId, justification, documentPath];
}