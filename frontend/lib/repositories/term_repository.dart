import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ceriv_app/models/api_response.dart';
import 'package:ceriv_app/models/api_error.dart';
import 'package:ceriv_app/models/term.dart';
import 'package:ceriv_app/services/api_service.dart';
import 'package:ceriv_app/services/service_locator.dart';
import 'package:ceriv_app/services/storage_service.dart';

class TermRepository {
  final ApiService _apiService = getIt<ApiService>();
  final StorageService _storageService = getIt<StorageService>();
  final SupabaseClient _supabaseClient = getIt<SupabaseClient>();
  
  // Obter todos os termos disponíveis
  Future<ApiResponse<List<Term>>> getTerms() async {
    try {
      // Primeiro, tenta obter da API
      final response = await _apiService.get('/terms');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        final terms = data.map((json) => Term.fromJson(json)).toList();
        
        // Salva localmente para acesso offline
        await _saveTermsLocally(terms);
        
        return ApiResponse.success(terms);
      } else {
        // Se falhar, tenta obter do Supabase diretamente
        final supaResponse = await _supabaseClient
            .from('term_versions')
            .select('*')
            .order('created_at', ascending: false);
            
        if (supaResponse != null) {
          final List<Term> terms = (supaResponse as List)
              .map((json) => Term.fromJson(json))
              .toList();
              
          // Salva localmente
          await _saveTermsLocally(terms);
              
          return ApiResponse.success(terms);
        }
        
        // Se também falhar, tenta obter do armazenamento local
        return await _getLocalTerms();
      }
    } on SocketException {
      // Sem conexão, usa cache local
      return await _getLocalTerms();
    } catch (e) {
      debugPrint('Erro ao obter termos: $e');
      
      // Última tentativa: armazenamento local
      final localResponse = await _getLocalTerms();
      if (localResponse.isSuccess && localResponse.data != null && localResponse.data!.isNotEmpty) {
        return localResponse;
      }
      
      return ApiResponse.error(
        ApiError(
          code: 'UNKNOWN',
          message: 'Erro desconhecido ao obter termos',
        ),
      );
    }
  }
  
  // Obter um termo específico por ID
  Future<ApiResponse<Term>> getTermById(String id) async {
    try {
      final response = await _apiService.get('/terms/$id');
      
      if (response.statusCode == 200) {
        final term = Term.fromJson(response.data['data']);
        return ApiResponse.success(term);
      } else {
        // Tenta obter diretamente do Supabase
        final supaResponse = await _supabaseClient
            .from('term_versions')
            .select('*')
            .eq('id', id)
            .single();
        
        if (supaResponse != null) {
          final term = Term.fromJson(supaResponse);
          return ApiResponse.success(term);
        }
        
        // Tenta obter localmente
        return await _getLocalTermById(id);
      }
    } on SocketException {
      // Tenta obter localmente
      return await _getLocalTermById(id);
    } catch (e) {
      debugPrint('Erro ao obter termo: $e');
      
      // Última tentativa: local
      final localResponse = await _getLocalTermById(id);
      if (localResponse.isSuccess && localResponse.data != null) {
        return localResponse;
      }
      
      return ApiResponse.error(
        ApiError(
          code: 'UNKNOWN',
          message: 'Erro desconhecido ao obter termo',
        ),
      );
    }
  }
  
  // Aceitar um termo
  Future<ApiResponse<bool>> acceptTerm(String termId) async {
    try {
      // Primeiro, tenta via API REST
      final response = await _apiService.post(
        '/terms/$termId/accept',
        {},
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Salvar localmente
        await _storageService.saveTermAcceptance(termId);
        return ApiResponse.success(true);
      } 
      
      // Se falhar, tenta diretamente via Supabase
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId != null) {
        await _supabaseClient.from('term_acceptances').insert({
          'term_id': termId,
          'user_id': userId,
          'accepted_at': DateTime.now().toIso8601String(),
        });
        
        // Salvar localmente
        await _storageService.saveTermAcceptance(termId);
        return ApiResponse.success(true);
      }
      
      return ApiResponse.error(
        ApiError(
          code: 'AUTH_ERROR',
          message: 'Usuário não autenticado para aceitar o termo',
        ),
      );
    } on SocketException {
      // Sem internet - salva localmente e marca para sincronizar depois
      await _storageService.saveTermAcceptance(termId);
      await _storageService.addPendingTermAcceptance(termId);
      
      return ApiResponse.success(true);
    } catch (e) {
      debugPrint('Erro ao aceitar termo: $e');
      return ApiResponse.error(
        ApiError(
          code: 'UNKNOWN',
          message: 'Erro desconhecido ao aceitar termo',
        ),
      );
    }
  }
  
  // Sincronizar aceitações de termos pendentes
  Future<bool> syncPendingTermAcceptances() async {
    try {
      final pendingTerms = await _storageService.getPendingTermAcceptances();
      
      if (pendingTerms.isEmpty) {
        return true;
      }
      
      bool allSuccess = true;
      
      for (final termId in pendingTerms) {
        try {
          final response = await acceptTerm(termId);
          if (response.isSuccess) {
            await _storageService.removePendingTermAcceptance(termId);
          } else {
            allSuccess = false;
          }
        } catch (e) {
          allSuccess = false;
        }
      }
      
      return allSuccess;
    } catch (e) {
      return false;
    }
  }
  
  // Verificar se todos os termos obrigatórios foram aceitos
  Future<ApiResponse<bool>> verifyAllTermsAccepted() async {
    try {
      final response = await _apiService.get('/terms/verify');
      
      if (response.statusCode == 200) {
        final bool allAccepted = response.data['allAccepted'] ?? false;
        return ApiResponse.success(allAccepted);
      } else {
        // Tenta verificar localmente
        return ApiResponse.success(await _verifyLocalTermsAcceptance());
      }
    } on SocketException {
      // Verificar localmente
      return ApiResponse.success(await _verifyLocalTermsAcceptance());
    } catch (e) {
      debugPrint('Erro ao verificar termos aceitos: $e');
      
      // Tenta verificar localmente como último recurso
      return ApiResponse.success(await _verifyLocalTermsAcceptance());
    }
  }
  
  // Baixar PDF do termo
  Future<ApiResponse<String>> downloadTermPdf(String termId) async {
    try {
      final response = await _apiService.get('/terms/$termId/pdf', responseType: 'arraybuffer');
      
      if (response.statusCode == 200) {
        // Salvar o PDF localmente
        final path = await _storageService.saveTermPdf(termId, response.data);
        return ApiResponse.success(path);
      } else {
        // Tentar obter do Supabase Storage
        final bytes = await _supabaseClient
            .storage
            .from('terms')
            .download('$termId.pdf');
        
        if (bytes != null) {
          final path = await _storageService.saveTermPdf(termId, bytes);
          return ApiResponse.success(path);
        }
        
        return ApiResponse.error(
          ApiError(
            code: 'NOT_FOUND',
            message: 'PDF do termo não encontrado',
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao baixar PDF do termo: $e');
      return ApiResponse.error(
        ApiError(
          code: 'DOWNLOAD_ERROR',
          message: 'Não foi possível baixar o PDF do termo',
        ),
      );
    }
  }
  
  // Métodos privados para manipulação local dos termos
  
  // Salvar termos localmente
  Future<void> _saveTermsLocally(List<Term> terms) async {
    await _storageService.saveTerms(terms);
  }
  
  // Obter termos do armazenamento local
  Future<ApiResponse<List<Term>>> _getLocalTerms() async {
    try {
      final terms = await _storageService.getTerms();
      
      if (terms.isEmpty) {
        return ApiResponse.error(
          ApiError(
            code: 'NO_LOCAL_DATA',
            message: 'Nenhum termo disponível localmente',
          ),
        );
      }
      
      return ApiResponse.success(terms);
    } catch (e) {
      return ApiResponse.error(
        ApiError(
          code: 'LOCAL_ERROR',
          message: 'Erro ao obter termos localmente',
        ),
      );
    }
  }
  
  // Obter um termo específico do armazenamento local
  Future<ApiResponse<Term>> _getLocalTermById(String id) async {
    try {
      final terms = await _storageService.getTerms();
      final term = terms.firstWhere((t) => t.id == id, orElse: () => throw Exception('Termo não encontrado'));
      
      return ApiResponse.success(term);
    } catch (e) {
      return ApiResponse.error(
        ApiError(
          code: 'LOCAL_ERROR',
          message: 'Termo não encontrado localmente',
        ),
      );
    }
  }
  
  // Verificação local de aceitação de termos
  Future<bool> _verifyLocalTermsAcceptance() async {
    try {
      // Obter IDs de termos aceitos localmente
      final List<String> acceptedTerms = await _storageService.getAcceptedTerms();
      
      // Obter termos obrigatórios do cache local
      final terms = await _storageService.getTerms();
      final requiredTerms = terms.where((term) => term.isRequired).toList();
      
      if (requiredTerms.isEmpty) {
        // Se não conseguirmos obter os termos obrigatórios, assumimos que falta aceitação
        return false;
      }
      
      // Verificar se todos os termos obrigatórios estão aceitos
      for (final term in requiredTerms) {
        if (!acceptedTerms.contains(term.id)) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Erro na verificação local de termos: $e');
      return false;
    }
  }
}