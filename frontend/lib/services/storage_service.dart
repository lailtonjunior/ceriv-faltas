import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ceriv_app/models/term.dart';
import 'package:ceriv_app/models/offline_operation.dart';
import 'package:ceriv_app/services/service_locator.dart';

/// Serviço para gerenciar armazenamento local e persistência de dados
class StorageService {
  late SharedPreferences _preferences;
  
  /// Inicializa o serviço de armazenamento
  Future<void> init() async {
    _preferences = getIt<SharedPreferences>();
  }
  
  /// Seção: Autenticação ///
  
  /// Verifica se o usuário está autenticado localmente
  Future<bool> isAuthenticated() async {
    return _preferences.getString('auth_token') != null;
  }
  
  /// Salva o token de autenticação
  Future<void> saveAuthToken(String token) async {
    await _preferences.setString('auth_token', token);
  }
  
  /// Obtém o token de autenticação
  Future<String?> getAuthToken() async {
    return _preferences.getString('auth_token');
  }
  
  /// Salva os dados do usuário autenticado
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _preferences.setString('user_data', jsonEncode(userData));
  }
  
  /// Obtém os dados do usuário autenticado
  Future<Map<String, dynamic>?> getUserData() async {
    final userData = _preferences.getString('user_data');
    if (userData == null) return null;
    return jsonDecode(userData) as Map<String, dynamic>;
  }
  
  /// Remove todos os dados de autenticação (logout)
  Future<void> clearAuthData() async {
    await _preferences.remove('auth_token');
    await _preferences.remove('user_data');
  }
  
  /// Seção: Configurações de Tema ///
  
  /// Verifica se o tema escuro está ativado
  Future<bool> isDarkMode() async {
    return _preferences.getBool('dark_mode') ?? false;
  }
  
  /// Define o modo do tema (claro/escuro)
  Future<void> setDarkMode(bool isDark) async {
    await _preferences.setBool('dark_mode', isDark);
  }
  
  /// Seção: Termos de Uso ///
  
  /// Salva a aceitação de um termo
  Future<void> saveTermAcceptance(String termId) async {
    final List<String> acceptedTerms = await getAcceptedTerms();
    
    if (!acceptedTerms.contains(termId)) {
      acceptedTerms.add(termId);
      await _preferences.setStringList('accepted_terms', acceptedTerms);
    }
  }
  
  /// Obtém a lista de termos aceitos
  Future<List<String>> getAcceptedTerms() async {
    return _preferences.getStringList('accepted_terms') ?? [];
  }
  
  /// Verifica se um termo específico foi aceito
  Future<bool> isTermAccepted(String termId) async {
    final List<String> acceptedTerms = await getAcceptedTerms();
    return acceptedTerms.contains(termId);
  }
  
  /// Adiciona um termo à lista de aceitações pendentes (quando offline)
  Future<void> addPendingTermAcceptance(String termId) async {
    final List<String> pendingTerms = await getPendingTermAcceptances();
    
    if (!pendingTerms.contains(termId)) {
      pendingTerms.add(termId);
      await _preferences.setStringList('pending_term_acceptances', pendingTerms);
    }
  }
  
  /// Obtém a lista de termos com aceitação pendente
  Future<List<String>> getPendingTermAcceptances() async {
    return _preferences.getStringList('pending_term_acceptances') ?? [];
  }
  
  /// Remove um termo da lista de aceitações pendentes (após sincronização)
  Future<void> removePendingTermAcceptance(String termId) async {
    final List<String> pendingTerms = await getPendingTermAcceptances();
    
    if (pendingTerms.contains(termId)) {
      pendingTerms.remove(termId);
      await _preferences.setStringList('pending_term_acceptances', pendingTerms);
    }
  }
  
  /// Salva a lista de termos localmente
  Future<void> saveTerms(List<Term> terms) async {
    final List<Map<String, dynamic>> termsList = terms.map((t) => t.toJson()).toList();
    await _preferences.setString('cached_terms', jsonEncode(termsList));
  }
  
  /// Obtém a lista de termos do armazenamento local
  Future<List<Term>> getTerms() async {
    final String? termsJson = _preferences.getString('cached_terms');
    
    if (termsJson == null) return [];
    
    final List<dynamic> termsList = jsonDecode(termsJson);
    return termsList.map((json) => Term.fromJson(json)).toList();
  }
  
  /// Salva um PDF de termo localmente
  Future<String> saveTermPdf(String termId, dynamic data) async {
    final directory = await _getDocumentsDirectory();
    final file = File('${directory.path}/terms/$termId.pdf');
    
    // Certifique-se de que o diretório existe
    await Directory('${directory.path}/terms').create(recursive: true);
    
    if (data is Uint8List) {
      await file.writeAsBytes(data);
    } else if (data is String) {
      await file.writeAsString(data);
    } else {
      throw Exception('Formato de dados não suportado para salvar PDF');
    }
    
    return file.path;
  }
  
  /// Obtém o caminho do PDF de um termo
  Future<String?> getTermPdfPath(String termId) async {
    final directory = await _getDocumentsDirectory();
    final file = File('${directory.path}/terms/$termId.pdf');
    
    if (await file.exists()) {
      return file.path;
    }
    
    return null;
  }
  
  /// Seção: Operações Offline ///
  
  /// Adiciona uma operação à fila offline
  Future<void> addOfflineOperation(OfflineOperation operation) async {
    final List<OfflineOperation> operations = await getOfflineOperations();
    operations.add(operation);
    
    final List<Map<String, dynamic>> operationList = 
        operations.map((op) => op.toJson()).toList();
        
    await _preferences.setString('offline_operations', jsonEncode(operationList));
  }
  
  /// Obtém todas as operações offline pendentes
  Future<List<OfflineOperation>> getOfflineOperations() async {
    final String? operationsJson = _preferences.getString('offline_operations');
    
    if (operationsJson == null) return [];
    
    final List<dynamic> operationList = jsonDecode(operationsJson);
    return operationList.map((json) => OfflineOperation.fromJson(json)).toList();
  }
  
  /// Remove uma operação da fila offline
  Future<void> removeOfflineOperation(String id) async {
    final List<OfflineOperation> operations = await getOfflineOperations();
    operations.removeWhere((op) => op.id == id);
    
    final List<Map<String, dynamic>> operationList = 
        operations.map((op) => op.toJson()).toList();
        
    await _preferences.setString('offline_operations', jsonEncode(operationList));
  }
  
  /// Limpa todas as operações offline
  Future<void> clearOfflineOperations() async {
    await _preferences.remove('offline_operations');
  }
  
  /// Seção: Utilitários ///
  
  /// Obtém o diretório de documentos
  Future<Directory> _getDocumentsDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Operação não suportada em ambiente web');
    }
    
    return await getApplicationDocumentsDirectory();
  }
  
  /// Limpa todos os dados armazenados (reset completo)
  Future<void> clearAllData() async {
    await _preferences.clear();
  }
}