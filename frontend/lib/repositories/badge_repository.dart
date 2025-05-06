import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ceriv_app/models/api_response.dart';
import 'package:ceriv_app/models/api_error.dart';
import 'package:ceriv_app/models/badge.dart';
import 'package:ceriv_app/services/api_service.dart';
import 'package:ceriv_app/services/service_locator.dart';
import 'package:ceriv_app/services/storage_service.dart';

/// Repositório para gerenciar operações relacionadas a badges (conquistas)
class BadgeRepository {
  final ApiService _apiService = getIt<ApiService>();
  final StorageService _storageService = getIt<StorageService>();
  final SupabaseClient _supabaseClient = getIt<SupabaseClient>();
  
  /// Obtém todos os badges disponíveis
  Future<ApiResponse<List<Badge>>> getBadges() async {
    try {
      final response = await _apiService.get('/badges');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        final badges = data.map((json) => Badge.fromJson(json)).toList();
        
        // Salvar localmente para acesso offline
        await _saveBadgesLocally(badges);
        
        return ApiResponse.success(badges);
      } else {
        // Tentar obter via Supabase
        try {
          final data = await _supabaseClient
              .from('badges')
              .select('*')
              .order('order', ascending: true);
              
          if (data != null) {
            final badges = (data as List).map((json) => Badge.fromJson(json)).toList();
            
            // Salvar localmente
            await _saveBadgesLocally(badges);
            
            return ApiResponse.success(badges);
          }
        } catch (supabaseError) {
          debugPrint('Erro ao obter badges do Supabase: $supabaseError');
        }
        
        // Tentar obter do armazenamento local
        return await _getLocalBadges();
      }
    } on SocketException {
      // Sem conexão, usar cache local
      return await _getLocalBadges();
    } catch (e) {
      debugPrint('Erro ao obter badges: $e');
      
      // Última tentativa: armazenamento local
      final localResponse = await _getLocalBadges();
      if (localResponse.isSuccess && localResponse.data != null && localResponse.data!.isNotEmpty) {
        return localResponse;
      }
      
      return ApiResponse.error(
        ApiError(
          code: 'UNKNOWN',
          message: 'Erro ao obter badges',
        ),
      );
    }
  }
  
  /// Obtém os badges conquistados pelo usuário
  Future<ApiResponse<List<Badge>>> getEarnedBadges() async {
    try {
      final response = await _apiService.get('/badges/earned');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        final badges = data.map((json) => Badge.fromJson(json)).toList();
        
        // Salvar localmente
        await _saveEarnedBadgesLocally(badges);
        
        return ApiResponse.success(badges);
      } else {
        // Tentar obter via Supabase
        try {
          final userId = _supabaseClient.auth.currentUser?.id;
          
          if (userId == null) {
            throw Exception('Usuário não autenticado');
          }
          
          final data = await _supabaseClient
              .from('user_badges')
              .select('*, badges(*)')
              .eq('user_id', userId)
              .order('earned_at', ascending: false);
              
          if (data != null) {
            final badges = (data as List).map((json) {
              // Combinar os dados do badge com os dados de conquista
              final badge = Badge.fromJson(json['badges']);
              return badge.copyWith(
                isEarned: true,
                earnedAt: DateTime.parse(json['earned_at']),
              );
            }).toList();
            
            // Salvar localmente
            await _saveEarnedBadgesLocally(badges);
            
            return ApiResponse.success(badges);
          }
        } catch (supabaseError) {
          debugPrint('Erro ao obter badges conquistados do Supabase: $supabaseError');
        }
        
        // Tentar obter do armazenamento local
        return await _getLocalEarnedBadges();
      }
    } on SocketException {
      // Sem conexão, usar cache local
      return await _getLocalEarnedBadges();
    } catch (e) {
      debugPrint('Erro ao obter badges conquistados: $e');
      
      // Última tentativa: armazenamento local
      final localResponse = await _getLocalEarnedBadges();
      if (localResponse.isSuccess && localResponse.data != null) {
        return localResponse;
      }
      
      return ApiResponse.error(
        ApiError(
          code: 'UNKNOWN',
          message: 'Erro ao obter badges conquistados',
        ),
      );
    }
  }
  
  /// Obtém detalhes de um badge específico
  Future<ApiResponse<Badge>> getBadgeDetails(String badgeId) async {
    try {
      final response = await _apiService.get('/badges/$badgeId');
      
      if (response.statusCode == 200) {
        final badge = Badge.fromJson(response.data['data']);
        return ApiResponse.success(badge);
      } else {
        // Tentar obter via Supabase
        try {
          final data = await _supabaseClient
              .from('badges')
              .select('*')
              .eq('id', badgeId)
              .single();
              
          if (data != null) {
            final badge = Badge.fromJson(data);
            return ApiResponse.success(badge);
          }
        } catch (supabaseError) {
          debugPrint('Erro ao obter detalhes do badge do Supabase: $supabaseError');
        }
        
        // Tentar obter do armazenamento local
        return await _getLocalBadgeById(badgeId);
      }
    } on SocketException {
      // Sem conexão, usar cache local
      return await _getLocalBadgeById(badgeId);
    } catch (e) {
      debugPrint('Erro ao obter detalhes do badge: $e');
      
      // Última tentativa: armazenamento local
      final localResponse = await _getLocalBadgeById(badgeId);
      if (localResponse.isSuccess && localResponse.data != null) {
        return localResponse;
      }
      
      return ApiResponse.error(
        ApiError(
          code: 'UNKNOWN',
          message: 'Erro ao obter detalhes do badge',
        ),
      );
    }
  }
  
  /// Métodos privados para manipulação local
  
  /// Salva badges localmente
  Future<void> _saveBadgesLocally(List<Badge> badges) async {
    final List<Map<String, dynamic>> badgesList = badges.map((b) => b.toJson()).toList();
    await _storageService.setString('cached_badges', badgesList.toString());
  }
  
  /// Salva badges conquistados localmente
  Future<void> _saveEarnedBadgesLocally(List<Badge> badges) async {
    final List<Map<String, dynamic>> badgesList = badges.map((b) => b.toJson()).toList();
    await _storageService.setString('cached_earned_badges', badgesList.toString());
  }
  
  /// Obtém badges do armazenamento local
  Future<ApiResponse<List<Badge>>> _getLocalBadges() async {
    try {
      final String? badgesJson = await _storageService.getString('cached_badges');
      
      if (badgesJson == null || badgesJson.isEmpty) {
        return ApiResponse.error(
          ApiError(
            code: 'NO_LOCAL_DATA',
            message: 'Nenhum badge disponível localmente',
          ),
        );
      }
      
      final List<dynamic> badgesList = badgesJson as List<dynamic>;
      final badges = badgesList.map((json) => Badge.fromJson(json)).toList();
      
      return ApiResponse.success(badges);
    } catch (e) {
      return ApiResponse.error(
        ApiError(
          code: 'LOCAL_ERROR',
          message: 'Erro ao obter badges localmente',
        ),
      );
    }
  }
  
  /// Obtém badges conquistados do armazenamento local
  Future<ApiResponse<List<Badge>>> _getLocalEarnedBadges() async {
    try {
      final String? badgesJson = await _storageService.getString('cached_earned_badges');
      
      if (badgesJson == null || badgesJson.isEmpty) {
        return ApiResponse.error(
          ApiError(
            code: 'NO_LOCAL_DATA',
            message: 'Nenhum badge conquistado disponível localmente',
          ),
        );
      }
      
      final List<dynamic> badgesList = badgesJson as List<dynamic>;
      final badges = badgesList.map((json) => Badge.fromJson(json)).toList();
      
      return ApiResponse.success(badges);
    } catch (e) {
      return ApiResponse.error(
        ApiError(
          code: 'LOCAL_ERROR',
          message: 'Erro ao obter badges conquistados localmente',
        ),
      );
    }
  }
  
  /// Obtém um badge específico do armazenamento local
  Future<ApiResponse<Badge>> _getLocalBadgeById(String badgeId) async {
    try {
      final ApiResponse<List<Badge>> allBadges = await _getLocalBadges();
      
      if (!allBadges.isSuccess || allBadges.data == null) {
        // Tentar obter dos badges conquistados
        final ApiResponse<List<Badge>> earnedBadges = await _getLocalEarnedBadges();
        
        if (!earnedBadges.isSuccess || earnedBadges.data == null) {
          return ApiResponse.error(
            ApiError(
              code: 'NO_LOCAL_DATA',
              message: 'Badge não encontrado localmente',
            ),
          );
        }
        
        final badge = earnedBadges.data!.firstWhere(
          (b) => b.id == badgeId,
          orElse: () => throw Exception('Badge não encontrado'),
        );
        
        return ApiResponse.success(badge);
      }
      
      final badge = allBadges.data!.firstWhere(
        (b) => b.id == badgeId,
        orElse: () => throw Exception('Badge não encontrado'),
      );
      
      return ApiResponse.success(badge);
    } catch (e) {
      return ApiResponse.error(
        ApiError(
          code: 'LOCAL_ERROR',
          message: 'Badge não encontrado localmente',
        ),
      );
    }
  }
}