part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;

  const AuthAuthenticated({
    required this.user,
  });

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}

class AuthRegistrationSuccess extends AuthState {
  final String message;

  const AuthRegistrationSuccess({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}

class AuthPasswordResetSent extends AuthState {
  final String message;

  const AuthPasswordResetSent({
    required this.message,
  });

  @override
  List<Object?> get props => [message];
}

class AuthProfileUpdated extends AuthState {
  final User user;
  final String message;

  const AuthProfileUpdated({
    required this.user,
    this.message = 'Perfil atualizado com sucesso',
  });

  @override
  List<Object?> get props => [user, message];
}

class AuthPasswordUpdated extends AuthState {
  final String message;

  const AuthPasswordUpdated({
    this.message = 'Senha atualizada com sucesso',
  });

  @override
  List<Object?> get props => [message];
}