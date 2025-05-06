// lib/blocs/auth/auth_event.dart
import 'package:equatable/equatable.dart';
import 'package:ceriv_app/models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthEvent extends AuthEvent {}

class SignInWithEmailEvent extends AuthEvent {
  final String email;
  final String password;

  const SignInWithEmailEvent({required this.email, required this.password});

  @override
  List<Object> get props => [email, password];
}

class SignInWithCPFEvent extends AuthEvent {
  final String cpf;
  final String password;

  const SignInWithCPFEvent({required this.cpf, required this.password});

  @override
  List<Object> get props => [cpf, password];
}

class RegisterEvent extends AuthEvent {
  final UserModel userData;
  final String password;

  const RegisterEvent({required this.userData, required this.password});

  @override
  List<Object> get props => [userData, password];
}

class SignOutEvent extends AuthEvent {}

class ForgotPasswordEvent extends AuthEvent {
  final String email;

  const ForgotPasswordEvent({required this.email});

  @override
  List<Object> get props => [email];
}

class ForgotPasswordByCPFEvent extends AuthEvent {
  final String cpf;

  const ForgotPasswordByCPFEvent({required this.cpf});

  @override
  List<Object> get props => [cpf];
}

class UpdateUserEvent extends AuthEvent {
  final UserModel userData;

  const UpdateUserEvent({required this.userData});

  @override
  List<Object> get props => [userData];
}