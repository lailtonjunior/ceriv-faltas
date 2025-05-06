part of 'connectivity_bloc.dart';

abstract class ConnectivityState extends Equatable {
  const ConnectivityState();
  
  @override
  List<Object?> get props => [];
}

class ConnectivityInitial extends ConnectivityState {}

class ConnectivityOnline extends ConnectivityState {}

class ConnectivityOffline extends ConnectivityState {}

class ConnectivityError extends ConnectivityState {
  final String message;

  const ConnectivityError({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}