import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'package:ceriv_app/models/user.dart';
import 'package:ceriv_app/services/auth_service.dart';
import 'package:ceriv_app/services/service_locator.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService = getIt<AuthService>();

  AuthBloc() : super(AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<LoginEvent>(_onLogin);
    on<RegisterEvent>(_onRegister);
    on<LogoutEvent>(_onLogout);
    on<ResetPasswordEvent>(_onResetPassword);
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());

      // Verificar se já está autenticado
      final isAuthenticated = _authService.isAuthenticated;
      final user = _authService.currentUser;

      if (isAuthenticated && user != null) {
        emit(AuthAuthenticated(user: user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      debugPrint('Erro ao verificar status de autenticação: $e');
      emit(AuthError(message: 'Erro ao verificar status de autenticação'));
    }
  }

  Future<void> _onLogin(
    LoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());

      // Realizar login
      final response = await _authService.loginWithEmailAndPassword(
        event.email,
        event.password,
      );

      if (response.isSuccess && response.data != null) {
        // Login bem-sucedido
        emit(AuthAuthenticated(user: response.data!));
      } else {
        // Erro de login
        emit(AuthError(
          message: response.error?.message ?? 'Falha na autenticação',
        ));
      }
    } catch (e) {
      debugPrint('Erro durante login: $e');
      emit(AuthError(message: 'Erro durante autenticação: $e'));
    }
  }

  Future<void> _onRegister(
    RegisterEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());

      // Realizar cadastro
      final response = await _authService.registerWithEmailAndPassword(
        event.email,
        event.password,
        event.name,
      );

      if (response.isSuccess && response.data != null) {
        // Cadastro bem-sucedido
        emit(AuthAuthenticated(user: response.data!));
      } else if (response.statusCode == 200 && response.message != null) {
        // Cadastro criado, mas precisa de confirmação (e.g., email)
        emit(AuthRegistrationSuccess(message: response.message!));
      } else {
        // Erro no cadastro
        emit(AuthError(
          message: response.error?.message ?? 'Falha no cadastro',
        ));
      }
    } catch (e) {
      debugPrint('Erro durante cadastro: $e');
      emit(AuthError(message: 'Erro durante cadastro: $e'));
    }
  }

  Future<void> _onLogout(
    LogoutEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());

      // Realizar logout
      await _authService.logout();

      emit(AuthUnauthenticated());
    } catch (e) {
      debugPrint('Erro durante logout: $e');
      emit(AuthError(message: 'Erro durante logout: $e'));
    }
  }

  Future<void> _onResetPassword(
    ResetPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());

      // Solicitar reset de senha
      final response = await _authService.resetPassword(event.email);

      if (response.isSuccess) {
        // Reset solicitado com sucesso
        emit(AuthPasswordResetSent(
          message: response.message ?? 'Instruções de recuperação enviadas para seu email',
        ));
      } else {
        // Erro ao solicitar reset
        emit(AuthError(
          message: response.error?.message ?? 'Falha ao solicitar recuperação de senha',
        ));
      }
    } catch (e) {
      debugPrint('Erro ao solicitar reset de senha: $e');
      emit(AuthError(message: 'Erro ao solicitar recuperação de senha: $e'));
    }
  }
}