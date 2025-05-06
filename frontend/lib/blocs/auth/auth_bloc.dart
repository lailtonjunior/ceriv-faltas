// lib/blocs/auth/auth_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ceriv_app/blocs/auth/auth_event.dart';
import 'package:ceriv_app/blocs/auth/auth_state.dart';
import 'package:ceriv_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(AuthInitial()) {
    on<CheckAuthEvent>(_onCheckAuth);
    on<SignInWithEmailEvent>(_onSignInWithEmail);
    on<SignInWithCPFEvent>(_onSignInWithCPF);
    on<RegisterEvent>(_onRegister);
    on<SignOutEvent>(_onSignOut);
    on<ForgotPasswordEvent>(_onForgotPassword);
    on<ForgotPasswordByCPFEvent>(_onForgotPasswordByCPF);
    on<UpdateUserEvent>(_onUpdateUser);
  }

  Future<void> _onCheckAuth(
    CheckAuthEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await _authService.getCurrentUserData();
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(Unauthenticated());
    }
  }

  Future<void> _onSignInWithEmail(
    SignInWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithEmailAndPassword(
        event.email,
        event.password,
      );
      final user = await _authService.getCurrentUserData();
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(const AuthError('Falha ao obter dados do usuário.'));
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Usuário não encontrado.';
          break;
        case 'wrong-password':
          message = 'Senha incorreta.';
          break;
        case 'invalid-email':
          message = 'E-mail inválido.';
          break;
        case 'user-disabled':
          message = 'Usuário desativado.';
          break;
        default:
          message = 'Erro de autenticação: ${e.message}';
      }
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignInWithCPF(
    SignInWithCPFEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signInWithCPF(
        event.cpf,
        event.password,
      );
      final user = await _authService.getCurrentUserData();
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(const AuthError('Falha ao obter dados do usuário.'));
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Usuário não encontrado com este CPF.';
          break;
        case 'wrong-password':
          message = 'Senha incorreta.';
          break;
        case 'user-disabled':
          message = 'Usuário desativado.';
          break;
        default:
          message = 'Erro de autenticação: ${e.message}';
      }
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onRegister(
    RegisterEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.registerWithEmailAndPassword(
        event.userData.email,
        event.password,
        event.userData,
      );
      final user = await _authService.getCurrentUserData();
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(const AuthError('Falha ao obter dados do usuário.'));
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Este e-mail já está em uso.';
          break;
        case 'invalid-email':
          message = 'E-mail inválido.';
          break;
        case 'weak-password':
          message = 'Senha muito fraca.';
          break;
        default:
          message = 'Erro de registro: ${e.message}';
      }
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onSignOut(
    SignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onForgotPassword(
    ForgotPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.sendPasswordResetEmail(event.email);
      emit(PasswordResetSent());
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Usuário não encontrado com este e-mail.';
          break;
        case 'invalid-email':
          message = 'E-mail inválido.';
          break;
        default:
          message = 'Erro ao enviar e-mail de recuperação: ${e.message}';
      }
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onForgotPasswordByCPF(
    ForgotPasswordByCPFEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.sendPasswordResetEmailByCPF(event.cpf);
      emit(PasswordResetSent());
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Usuário não encontrado com este CPF.';
          break;
        default:
          message = 'Erro ao enviar e-mail de recuperação: ${e.message}';
      }
      emit(AuthError(message));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onUpdateUser(
    UpdateUserEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await _authService.updateUserData(event.userData);
      final user = await _authService.getCurrentUserData();
      if (user != null) {
        emit(UserUpdated(user));
        emit(Authenticated(user));
      } else {
        emit(const AuthError('Falha ao obter dados atualizados do usuário.'));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}