// lib/blocs/auth/auth_state.dart
import 'package:equatable/equatable.dart';
import 'package:ceriv_app/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final UserModel user;

  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object> get props => [message];
}

class PasswordResetSent extends AuthState {}

class UserUpdated extends AuthState {
  final UserModel user;

  const UserUpdated(this.user);

  @override
  List<Object?> get props => [user];
}