import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:ceriv_app/services/storage_service.dart';
import 'package:ceriv_app/services/service_locator.dart';
import 'package:ceriv_app/models/user.dart';
import 'package:ceriv_app/models/api_response.dart';
import 'package:ceriv_app/models/api_error.dart';

/// Serviço para autenticação de usuários.
class AuthService {
  // Serviços
  final StorageService _storageService = getIt<StorageService>();
  
  // Instâncias
  SupabaseClient get _supabase => Supabase.instance.client;
  
  // Chaves de armazenamento
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _userKey = 'current_user';
  static const String _expirationKey = 'token_expiration';
  
  // Estado
  User? _currentUser;
  String? _token;
  String? _refreshToken;
  DateTime? _tokenExpiration;
  bool _initialized = false;
  
  // Streams
  final _authStateController = StreamController<AuthState>.broadcast();
  Stream<AuthState> get authStateChanges => _authStateController.stream;
  
  /// Inicializa o serviço de autenticação.
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Carregar dados salvos
      _token = await _storageService.getString(_tokenKey);
      _refreshToken = await _storageService.getString(_refreshTokenKey);
      
      // Verificar se o token existe e não está expirado
      if (_token != null && _token!.isNotEmpty) {
        // Verificar expiração
        final expString = await _storageService.getString(_expirationKey);
        if (expString != null && expString.isNotEmpty) {
          _tokenExpiration = DateTime.parse(expString);
          
          // Se o token estiver expirado, tentar renovar
          if (_tokenExpiration!.isBefore(DateTime.now())) {
            await refreshToken();
          }
        }
        
        // Carregar dados do usuário
        final userJson = await _storageService.getString(_userKey);
        if (userJson != null && userJson.isNotEmpty) {
          _currentUser = User.fromJson(userJson);
        }
        
        // Notificar que o usuário está logado
        if (_currentUser != null) {
          _authStateController.add(AuthState.authenticated);
        } else {
          _authStateController.add(AuthState.unauthenticated);
        }
      } else {
        _authStateController.add(AuthState.unauthenticated);
      }
    } catch (e) {
      debugPrint('Erro ao inicializar AuthService: $e');
      _authStateController.add(AuthState.unauthenticated);
    }
    
    // Inscrever-se nas mudanças de autenticação do Supabase
    _supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      
      if (event == AuthChangeEvent.signedIn) {
        _handleSignIn(data.session);
      } else if (event == AuthChangeEvent.signedOut) {
        _handleSignOut();
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        _handleTokenRefresh(data.session);
      }
    });
    
    _initialized = true;
  }
  
  /// Realiza login com email e senha.
  Future<ApiResponse<User>> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // Autenticar com Supabase
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      // Verificar resposta
      if (response.session != null) {
        // Obter token do Supabase
        final supabaseToken = response.session!.accessToken;
        
        // Trocar token do Supabase por token da API
        final apiResponse = await _exchangeSupabaseToken(supabaseToken);
        
        if (apiResponse.error == null && apiResponse.data != null) {
          _authStateController.add(AuthState.authenticated);
          
          return ApiResponse(
            data: _currentUser!,
            statusCode: 200,
            message: 'Login realizado com sucesso',
          );
        } else {
          return ApiResponse(
            error: apiResponse.error,
            statusCode: apiResponse.statusCode,
          );
        }
      } else {
        return ApiResponse(
          error: ApiError(
            message: 'Falha na autenticação',
            statusCode: 401,
          ),
          statusCode: 401,
        );
      }
    } on AuthException catch (e) {
      return ApiResponse(
        error: ApiError(
          message: e.message,
          statusCode: 401,
        ),
        statusCode: 401,
      );
    } catch (e) {
      return ApiResponse(
        error: ApiError(
          message: 'Erro inesperado: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Realiza cadastro com email e senha.
  Future<ApiResponse<User>> registerWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      // Registrar no Supabase
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
        },
      );
      
      // Verificar resposta
      if (response.user != null) {
        // Obter token do Supabase
        if (response.session != null) {
          final supabaseToken = response.session!.accessToken;
          
          // Trocar token do Supabase por token da API
          final apiResponse = await _exchangeSupabaseToken(supabaseToken);
          
          if (apiResponse.error == null && apiResponse.data != null) {
            _authStateController.add(AuthState.authenticated);
            
            return ApiResponse(
              data: _currentUser!,
              statusCode: 200,
              message: 'Cadastro realizado com sucesso',
            );
          } else {
            return ApiResponse(
              error: apiResponse.error,
              statusCode: apiResponse.statusCode,
            );
          }
        } else {
          // Usuário criado, mas precisa confirmar email
          return ApiResponse(
            statusCode: 200,
            message: 'Verifique seu email para confirmar o cadastro',
          );
        }
      } else {
        return ApiResponse(
          error: ApiError(
            message: 'Falha no cadastro',
            statusCode: 400,
          ),
          statusCode: 400,
        );
      }
    } on AuthException catch (e) {
      return ApiResponse(
        error: ApiError(
          message: e.message,
          statusCode: 400,
        ),
        statusCode: 400,
      );
    } catch (e) {
      return ApiResponse(
        error: ApiError(
          message: 'Erro inesperado: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Realiza logout.
  Future<void> logout() async {
    try {
      // Logout do Supabase
      await _supabase.auth.signOut();
      
      // Limpar dados locais
      await _storageService.remove(_tokenKey);
      await _storageService.remove(_refreshTokenKey);
      await _storageService.remove(_userKey);
      await _storageService.remove(_expirationKey);
      
      // Redefinir estado
      _token = null;
      _refreshToken = null;
      _currentUser = null;
      _tokenExpiration = null;
      
      // Notificar mudança de estado
      _authStateController.add(AuthState.unauthenticated);
    } catch (e) {
      debugPrint('Erro ao fazer logout: $e');
    }
  }
  
  /// Recupera senha.
  Future<ApiResponse<void>> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      
      return ApiResponse(
        statusCode: 200,
        message: 'Email de recuperação enviado',
      );
    } on AuthException catch (e) {
      return ApiResponse(
        error: ApiError(
          message: e.message,
          statusCode: 400,
        ),
        statusCode: 400,
      );
    } catch (e) {
      return ApiResponse(
        error: ApiError(
          message: 'Erro inesperado: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Atualiza senha.
  Future<ApiResponse<void>> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
      
      return ApiResponse(
        statusCode: 200,
        message: 'Senha atualizada com sucesso',
      );
    } on AuthException catch (e) {
      return ApiResponse(
        error: ApiError(
          message: e.message,
          statusCode: 400,
        ),
        statusCode: 400,
      );
    } catch (e) {
      return ApiResponse(
        error: ApiError(
          message: 'Erro inesperado: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Atualiza FCM token para notificações.
  Future<void> updateFcmToken() async {
    try {
      // Verificar se o usuário está logado
      if (_currentUser == null || _token == null) return;
      
      // Obter token do FCM
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      
      // TODO: Atualizar token na API
      // await _apiService.put(
      //   'api/patients/fcm_token',
      //   data: {
      //     'fcm_token': fcmToken,
      //   },
      // );
    } catch (e) {
      debugPrint('Erro ao atualizar FCM token: $e');
    }
  }
  
  /// Renova o token de acesso.
  Future<bool> refreshToken() async {
    try {
      // Verificar se existe refresh token
      if (_refreshToken == null || _refreshToken!.isEmpty) {
        return false;
      }
      
      // Renovar token no Supabase
      // Nota: O Supabase gerencia a renovação automaticamente ao usar sua SDK
      
      // Renovar token na API
      // TODO: Implementar endpoint de renovação de token na API
      
      return true;
    } catch (e) {
      debugPrint('Erro ao renovar token: $e');
      return false;
    }
  }
  
  /// Troca o token do Supabase por um token da API.
  Future<ApiResponse<User>> _exchangeSupabaseToken(String supabaseToken) async {
    try {
      // TODO: Implementar chamada para API para trocar o token
      // Como este é um exemplo simplificado, vamos simular a troca
      
      // Simular token da API
      final apiToken = supabaseToken;
      
      // Decodificar token
      final decodedToken = JwtDecoder.decode(apiToken);
      
      // Extrair dados do usuário do token
      final userId = decodedToken['sub'] as String;
      final userEmail = decodedToken['email'] as String;
      final userName = decodedToken['user_metadata']?['name'] as String? ?? 'Usuário';
      final userRole = decodedToken['role'] as String? ?? 'patient';
      
      // Simular expiração do token (1 hora)
      final expiration = DateTime.now().add(const Duration(hours: 1));
      
      // Criar usuário
      _currentUser = User(
        id: int.tryParse(userId) ?? 0,
        email: userEmail,
        name: userName,
        role: userRole,
      );
      
      // Salvar token e dados do usuário
      _token = apiToken;
      _refreshToken = supabaseToken; // Usar o mesmo token por simplicidade
      _tokenExpiration = expiration;
      
      await _storageService.setString(_tokenKey, _token!);
      await _storageService.setString(_refreshTokenKey, _refreshToken!);
      await _storageService.setString(_userKey, _currentUser!.toJson());
      await _storageService.setString(_expirationKey, expiration.toIso8601String());
      
      // Atualizar FCM token
      updateFcmToken();
      
      return ApiResponse(
        data: _currentUser!,
        statusCode: 200,
      );
    } catch (e) {
      debugPrint('Erro ao trocar token: $e');
      return ApiResponse(
        error: ApiError(
          message: 'Erro ao trocar token: $e',
          statusCode: 500,
        ),
        statusCode: 500,
      );
    }
  }
  
  /// Manipula evento de login.
  void _handleSignIn(Session? session) {
    if (session != null) {
      final supabaseToken = session.accessToken;
      _exchangeSupabaseToken(supabaseToken);
    }
  }
  
  /// Manipula evento de logout.
  void _handleSignOut() {
    logout();
  }
  
  /// Manipula evento de renovação de token.
  void _handleTokenRefresh(Session? session) {
    if (session != null) {
      final supabaseToken = session.accessToken;
      _exchangeSupabaseToken(supabaseToken);
    }
  }
  
  /// Retorna o usuário atual.
  User? get currentUser => _currentUser;
  
  /// Verifica se o usuário está autenticado.
  bool get isAuthenticated => _currentUser != null && _token != null;
  
  /// Retorna o token de acesso.
  Future<String?> getToken() async {
    if (_token != null) {
      // Verificar se o token está expirado
      if (_tokenExpiration != null && _tokenExpiration!.isBefore(DateTime.now())) {
        // Tentar renovar o token
        final refreshed = await refreshToken();
        if (!refreshed) {
          // Se não foi possível renovar, retornar null
          return null;
        }
      }
      return _token;
    }
    return null;
  }
  
  /// Retorna o papel do usuário.
  String get userRole => _currentUser?.role ?? 'guest';
  
  /// Encerra o serviço.
  void dispose() {
    _authStateController.close();
  }
}

/// Estados de autenticação.
enum AuthState {
  /// Usuário não autenticado.
  unauthenticated,
  
  /// Usuário autenticado.
  authenticated,
  
  /// Autenticação em andamento.
  loading,
}