part of 'connectivity_bloc.dart';

abstract class ConnectivityEvent extends Equatable {
  const ConnectivityEvent();

  @override
  List<Object?> get props => [];
}

class ConnectivityStartMonitoring extends ConnectivityEvent {}

class ConnectivityStatusChanged extends ConnectivityEvent {
  final ConnectivityResult result;

  const ConnectivityStatusChanged(this.result);

  @override
  List<Object?> get props => [result];
}

class ConnectivityStopMonitoring extends ConnectivityEvent {}