import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:ceriv_app/services/auth_service.dart';
import 'package:ceriv_app/services/api_service.dart';
import 'package:ceriv_app/services/crypto_service.dart';
import 'package:ceriv_app/services/storage_service.dart';
import 'package:ceriv_app/services/service_locator.dart';
import 'package:ceriv_app/models/message.dart';
import 'package:ceriv_app/models/conversation.dart';
import 'package:ceriv_app/models/api_response.dart';

/// Serviço para gerenciamento de chat com criptografia.
class ChatService {
  // Serviços
  final ApiService _apiService = getIt<ApiService>();
  final AuthService _authService = getIt<AuthService>();
  final CryptoService _cryptoService = getIt<CryptoService>();
  final StorageService _storageService = getIt<StorageService>();
  
  // Cliente Socket.IO
  io.Socket? _socket;
  String _socketUrl = '';
  bool _isConnected = false;
  
  // Controllers para streams
  final _messagesController = StreamController<Message>.broadcast();
  final _typingController = StreamController<TypingEvent>.broadcast();
  final _conversationsController = StreamController<List<Conversation>>.broadcast();
  
  // Streams públicos
  Stream<Message> get onNewMessage => _messagesController.stream;
  Stream<TypingEvent> get onTyping => _typingController.stream;
  Stream<List<Conversation>> get conversationsStream => _conversationsController.stream;
  
  // Cache de mensagens por conversa
  final Map<String, List<Message>> _messagesCache = {};
  
  /// Inicializa o serviço de chat.
  Future<void> initialize() async {
    try {
      // Obter URL do Socket.IO do arquivo .env
      _socketUrl = dotenv.env['SOCKET_IO_URL'] ?? 'http://localhost:8001';
      
      // Conectar ao Socket.IO se usuário estiver autenticado
      if (_authService.isAuthenticated) {
        await _connectSocket();
      }
      
      // Inicializar par de chaves de criptografia
      await _initializeEncryptionKeys();
    } catch (e) {
      debugPrint('Erro ao inicializar ChatService: $e');
    }
  }
  
  /// Inicializa o par de chaves para criptografia.
  Future<void> _initializeEncryptionKeys() async {
    try {
      // Verificar se já existe um par de chaves salvo
      final privateKey = await _storageService.getSecureString('chat_private_key');
      final publicKey = await _storageService.getString('chat_public_key');
      
      if (privateKey == null || publicKey == null) {
        // Gerar novo par de chaves
        final keyPair = await _cryptoService.generateKeyPair();
        
        // Salvar chaves
        await _storageService.setSecureString('chat_private_key', keyPair.privateKey);
        await _storageService.setString('chat_public_key', keyPair.publicKey);
      }
    } catch (e) {
      debugPrint('Erro ao inicializar chaves de criptografia: $e');
    }
  }
  
  /// Conecta ao servidor Socket.IO.
  Future<void> _connectSocket() async {
    try {
      // Obter token de autenticação
      final token = await _authService.getToken();
      if (token == null) return;
      
      // Inicializar Socket.IO
      _socket = io.io(
        _socketUrl,
        io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .build(),
      );
      
      // Configurar handlers de eventos
      _setupSocketEventHandlers();
      
      // Conectar ao servidor
      _socket?.connect();
    } catch (e) {
      debugPrint('Erro ao conectar ao Socket.IO: $e');
    }
  }
  
  /// Configura os handlers de eventos do Socket.IO.
  void _setupSocketEventHandlers() {
    _socket?.on('connect', (_) {
      debugPrint('Conectado ao Socket.IO');
      _isConnected = true;
    });
    
    _socket?.on('disconnect', (_) {
      debugPrint('Desconectado do Socket.IO');
      _isConnected = false;
    });
    
    _socket?.on('error', (error) {
      debugPrint('Erro no Socket.IO: $error');
    });
    
    _socket?.on('auth_success', (data) {
      debugPrint('Autenticação no Socket.IO bem-sucedida: $data');
    });
    
    _socket?.on('new_message', (data) async {
      debugPrint('Nova mensagem recebida: $data');
      try {
        // Converter dados para Message
        final message = Message.fromMap(data);
        
        // Descriptografar mensagem, se necessário
        if (message.encrypted) {
          await _decryptMessage(message);
        }
        
        // Adicionar mensagem ao cache
        _addMessageToCache(message);
        
        // Emitir evento de nova mensagem
        _messagesController.add(message);
      } catch (e) {
        debugPrint('Erro ao processar nova mensagem: $e');
      }
    });
    
    _socket?.on('messages_read', (data) {
      debugPrint('Mensagens lidas: $data');
      // Atualizar status de leitura das mensagens no cache
      if (data['message_ids'] is List) {
        for (final id in data['message_ids']) {
          _updateMessageReadStatus(id, true);
        }
      }
    });
    
    _socket?.on('typing', (data) {
      debugPrint('Evento de digitação: $data');
      // Emitir evento de digitação
      _typingController.add(
        TypingEvent(
          userId: data['user_id'],
          conversationId: data['conversation_id'],
          timestamp: DateTime.parse(data['timestamp']),
        ),
      );
    });
    
    _socket?.on('conversation_history', (data) async {
      debugPrint('Histórico de conversa recebido: ${data['conversation_id']}');
      try {
        final conversationId = data['conversation_id'] as String;
        final messages = (data['messages'] as List)
          .map((m) => Message.fromMap(m))
          .toList();
        
        // Descriptografar mensagens, se necessário
        for (final message in messages) {
          if (message.encrypted) {
            await _decryptMessage(message);
          }
        }
        
        // Atualizar cache
        _messagesCache[conversationId] = messages;
      } catch (e) {
        debugPrint('Erro ao processar histórico de conversa: $e');
      }
    });
  }
  
  /// Entra em uma sala de conversa.
  Future<void> joinConversation(String conversationId) async {
    if (!_isConnected) {
      await _connectSocket();
    }
    
    _socket?.emit('join_conversation', {'conversation_id': conversationId});
    
    // Solicitar histórico da conversa
    _socket?.emit('get_conversation_history', {
      'conversation_id': conversationId,
      'limit': 50,
      'offset': 0,
    });
  }
  
  /// Sai de uma sala de conversa.
  void leaveConversation(String conversationId) {
    _socket?.emit('leave_conversation', {'conversation_id': conversationId});
  }
  
  /// Envia uma mensagem.
  Future<bool> sendMessage({
    required String conversationId,
    required String content,
    required String recipientId,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    try {
      if (!_isConnected) {
        await _connectSocket();
      }
      
      // Verificar se já está em uma sala
      await joinConversation(conversationId);
      
      // Criptografar mensagem
      final encryptedContent = await _encryptMessage(content, recipientId);
      
      // Preparar dados da mensagem
      final messageData = {
        'conversation_id': conversationId,
        'content': encryptedContent,
        'encrypted': true,
        'sender_type': _authService.userRole,
      };
      
      // Adicionar anexo, se houver
      if (attachmentUrl != null) {
        messageData['attachment_url'] = attachmentUrl;
        messageData['attachment_type'] = attachmentType ?? 'file';
      }
      
      // Enviar mensagem
      _socket?.emit('send_message', messageData);
      
      return true;
    } catch (e) {
      debugPrint('Erro ao enviar mensagem: $e');
      return false;
    }
  }
  
  /// Marca mensagens como lidas.
  Future<void> markMessagesAsRead(String conversationId, List<String> messageIds) async {
    try {
      if (!_isConnected) {
        await _connectSocket();
      }
      
      // Enviar evento para marcar mensagens como lidas
      _socket?.emit('mark_as_read', {
        'conversation_id': conversationId,
        'message_ids': messageIds,
      });
      
      // Atualizar status de leitura no cache
      for (final id in messageIds) {
        _updateMessageReadStatus(id, true);
      }
    } catch (e) {
      debugPrint('Erro ao marcar mensagens como lidas: $e');
    }
  }
  
  /// Emite evento de digitação.
  void sendTypingEvent(String conversationId) {
    if (_isConnected) {
      _socket?.emit('user_typing', {'conversation_id': conversationId});
    }
  }
  
  /// Obtém o número de mensagens não lidas.
  Future<int> getUnreadCount(String conversationId) async {
    try {
      if (!_isConnected) {
        await _connectSocket();
      }
      
      // Se tiver no cache, contar as mensagens não lidas
      if (_messagesCache.containsKey(conversationId)) {
        return _messagesCache[conversationId]!
          .where((m) => !m.read && m.senderType != _authService.userRole)
          .length;
      }
      
      // Solicitar contagem ao servidor
      _socket?.emit('get_unread_count', {'conversation_id': conversationId});
      
      // Aguardar resposta (simplificado - em produção seria melhor usar Completer)
      return 0;
    } catch (e) {
      debugPrint('Erro ao obter contagem de não lidas: $e');
      return 0;
    }
  }
  
  /// Obtém as mensagens de uma conversa.
  Future<List<Message>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    try {
      // Verificar se existe no cache
      if (_messagesCache.containsKey(conversationId)) {
        // Se tiver mais que o limite, retornar
        if (_messagesCache[conversationId]!.length > offset + limit) {
          return _messagesCache[conversationId]!
            .skip(offset)
            .take(limit)
            .toList();
        }
      }
      
      // Solicitar ao servidor
      if (!_isConnected) {
        await _connectSocket();
      }
      
      await joinConversation(conversationId);
      
      _socket?.emit('get_conversation_history', {
        'conversation_id': conversationId,
        'limit': limit,
        'offset': offset,
      });
      
      // Aguardar resposta (simplificado - em produção seria melhor usar Completer)
      // Retornar o que tem no cache por enquanto
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_messagesCache.containsKey(conversationId)) {
        return _messagesCache[conversationId]!
          .skip(offset)
          .take(limit)
          .toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('Erro ao obter mensagens: $e');
      return [];
    }
  }
  
  /// Obtém a lista de conversas.
  Future<List<Conversation>> getConversations() async {
    try {
      // Buscar da API
      final response = await _apiService.get<List<Conversation>>(
        '/api/chat/conversations',
        fromJsonList: (data) => data
          .map((json) => Conversation.fromMap(json))
          .toList(),
      );
      
      if (response.error == null && response.dataList != null) {
        // Atualizar stream
        _conversationsController.add(response.dataList!);
        return response.dataList!;
      }
      
      return [];
    } catch (e) {
      debugPrint('Erro ao obter conversas: $e');
      return [];
    }
  }
  
  /// Cria uma nova conversa.
  Future<ApiResponse<Conversation>> createConversation(String recipientId) async {
    try {
      // Criar via API
      final response = await _apiService.post<Conversation>(
        '/api/chat/conversations',
        data: {'recipient_id': recipientId},
        fromJson: (json) => Conversation.fromMap(json),
      );
      
      if (response.error == null && response.data != null) {
        // Atualizar lista de conversas
        getConversations();
      }
      
      return response;
    } catch (e) {
      debugPrint('Erro ao criar conversa: $e');
      return ApiResponse(
        statusCode: 500,
        error: ApiError(
          message: 'Erro ao criar conversa: $e',
          statusCode: 500,
        ),
      );
    }
  }
  
  /// Criptografa uma mensagem.
  Future<String> _encryptMessage(String content, String recipientId) async {
    try {
      // Obter chaves
      final privateKey = await _storageService.getSecureString('chat_private_key');
      final recipientPublicKey = await _getRecipientPublicKey(recipientId);
      
      if (privateKey == null || recipientPublicKey == null) {
        throw Exception('Chaves de criptografia não encontradas');
      }
      
      // Criptografar mensagem
      final encrypted = await _cryptoService.encrypt(
        plaintext: content,
        senderPrivateKey: privateKey,
        recipientPublicKey: recipientPublicKey,
      );
      
      return encrypted;
    } catch (e) {
      debugPrint('Erro ao criptografar mensagem: $e');
      // Em caso de erro, retornar a mensagem original
      return content;
    }
  }
  
  /// Descriptografa uma mensagem.
  Future<void> _decryptMessage(Message message) async {
    try {
      // Se não estiver criptografada, não fazer nada
      if (!message.encrypted) return;
      
      // Obter chaves
      final privateKey = await _storageService.getSecureString('chat_private_key');
      final senderPublicKey = await _getSenderPublicKey(message.senderId);
      
      if (privateKey == null || senderPublicKey == null) {
        throw Exception('Chaves de criptografia não encontradas');
      }
      
      // Descriptografar mensagem
      final decrypted = await _cryptoService.decrypt(
        ciphertext: message.content,
        recipientPrivateKey: privateKey,
        senderPublicKey: senderPublicKey,
      );
      
      // Atualizar mensagem
      message.content = decrypted;
    } catch (e) {
      debugPrint('Erro ao descriptografar mensagem: $e');
      // Em caso de erro, indicar na mensagem
      message.content = '[Mensagem criptografada não pode ser exibida]';
    }
  }
  
  /// Obtém a chave pública do destinatário.
  Future<String?> _getRecipientPublicKey(String recipientId) async {
    try {
      // Verificar se já temos a chave em cache
      final cachedKey = await _storageService.getString('public_key_$recipientId');
      if (cachedKey != null) {
        return cachedKey;
      }
      
      // Buscar da API
      final response = await _apiService.get<String>(
        '/api/chat/public_key/$recipientId',
      );
      
      if (response.error == null && response.rawData != null) {
        final publicKey = response.rawData.toString();
        
        // Cachear a chave
        await _storageService.setString('public_key_$recipientId', publicKey);
        
        return publicKey;
      }
      
      return null;
    } catch (e) {
      debugPrint('Erro ao obter chave pública do destinatário: $e');
      return null;
    }
  }
  
  /// Obtém a chave pública do remetente.
  Future<String?> _getSenderPublicKey(String senderId) async {
    // Mesmo método, apenas com nome diferente para clareza
    return _getRecipientPublicKey(senderId);
  }
  
  /// Adiciona uma mensagem ao cache.
  void _addMessageToCache(Message message) {
    final conversationId = message.conversationId;
    
    if (!_messagesCache.containsKey(conversationId)) {
      _messagesCache[conversationId] = [];
    }
    
    // Verificar se a mensagem já existe no cache
    final existingIndex = _messagesCache[conversationId]!
      .indexWhere((m) => m.id == message.id);
    
    if (existingIndex >= 0) {
      // Atualizar mensagem existente
      _messagesCache[conversationId]![existingIndex] = message;
    } else {
      // Adicionar nova mensagem
      _messagesCache[conversationId]!.add(message);
      
      // Ordenar por timestamp
      _messagesCache[conversationId]!.sort((a, b) => 
        b.timestamp.compareTo(a.timestamp));
    }
  }
  
  /// Atualiza o status de leitura de uma mensagem.
  void _updateMessageReadStatus(String messageId, bool read) {
    // Procurar a mensagem em todas as conversas
    for (final conversationId in _messagesCache.keys) {
      final index = _messagesCache[conversationId]!
        .indexWhere((m) => m.id == messageId);
      
      if (index >= 0) {
        _messagesCache[conversationId]![index].read = read;
        _messagesCache[conversationId]![index].readAt = read ? DateTime.now() : null;
      }
    }
  }
  
  /// Verifica se está conectado ao Socket.IO.
  bool get isConnected => _isConnected;
  
  /// Encerra o serviço.
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _messagesController.close();
    _typingController.close();
    _conversationsController.close();
  }
}

/// Evento de digitação.
class TypingEvent {
  final String userId;
  final String conversationId;
  final DateTime timestamp;
  
  TypingEvent({
    required this.userId,
    required this.conversationId,
    required this.timestamp,
  });
}