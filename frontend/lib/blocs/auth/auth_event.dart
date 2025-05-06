part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;
  final bool rememberMe;

  const LoginEvent({
    required this.email,
    required this.password,
    this.rememberMe = false,
  });

  @override
  List<Object?> get props => [email, password, rememberMe];
}

class RegisterEvent extends AuthEvent {
  final String email;
  final String password;
  final String name;

  const RegisterEvent({
    required this.email,
    required this.password,
    required this.name,
  });

  @override
  List<Object?> get props => [email, password, name];
}

class LogoutEvent extends AuthEvent {
  const LogoutEvent();
}

class ResetPasswordEvent extends AuthEvent {
  final String email;

  const ResetPasswordEvent({
    required this.email,
  });

  @override
  List<Object?> get props => [email];
}

class UpdateProfileEvent extends AuthEvent {
  final User user;

  const UpdateProfileEvent({
    required this.user,
  });

  @override
  List<Object?> get props => [user];
}

class UpdatePasswordEvent extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  const UpdatePasswordEvent({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword];
}