import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ceriv_app/models/notification.dart' as app;
import 'package:ceriv_app/services/api_service.dart';
import 'package:ceriv_app/services/storage_service.dart';
import 'package:ceriv_app/services/service_locator.dart';

/// Serviço para gerenciamento de notificações.
class NotificationService {
  // Instâncias
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotifications =
      FlutterLocalNotificationsPlugin();
  
  // Serviços
  static final ApiService _apiService = getIt<ApiService>();
  static final StorageService _storageService = getIt<StorageService>();
  
  // Controlador de stream para notificações
  static final _notificationController = StreamController<app.Notification>.broadcast();
  static Stream<app.Notification> get onNotification => _notificationController.stream;
  
  // Chave para armazenar notificações
  static const String _notificationsKey = 'local_notifications';
  
  // Lista local de notificações
  static List<app.Notification> _notifications = [];
  
  // Controlador de stream para a lista de notificações
  static final _notificationsListController = StreamController<List<app.Notification>>.broadcast();
  static Stream<List<app.Notification>> get notificationsStream => _notificationsListController.stream;
  
  /// Inicializa o serviço de notificações.
  static Future<void> initialize() async {
    try {
      // Solicitar permissões
      await _requestPermissions();
      
      // Inicializar notificações locais
      await _initializeLocalNotifications();
      
      // Configurar handlers do FCM
      _setupFcmHandlers();
      
      // Carregar notificações salvas
      await _loadNotifications();
      
      debugPrint('Serviço de notificações inicializado');
    } catch (e) {
      debugPrint('Erro ao inicializar NotificationService: $e');
    }
  }
  
  /// Solicita permissões para notificações.
  static Future<void> _requestPermissions() async {
    try {
      // Firebase Messaging
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      debugPrint('Permissão de notificação FCM: ${settings.authorizationStatus}');
      
      // Permissões específicas para iOS
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      
      // Permissões para notificações locais
      await _flutterLocalNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestPermission();
          
      await _flutterLocalNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } catch (e) {
      debugPrint('Erro ao solicitar permissões de notificação: $e');
    }
  }
  
  /// Inicializa o plugin de notificações locais.
  static Future<void> _initializeLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _flutterLocalNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );
    } catch (e) {
      debugPrint('Erro ao inicializar notificações locais: $e');
    }
  }
  
  /// Configura handlers para mensagens do FCM.
  static void _setupFcmHandlers() {
    // Listener para mensagens em primeiro plano
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Listener para quando o app é aberto via notificação
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    
    // Verificar mensagem inicial
    _fcm.getInitialMessage().then((message) {
      if (message != null) {
        _handleInitialMessage(message);
      }
    });
  }
  
  /// Manipula mensagens recebidas em primeiro plano.
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Mensagem em primeiro plano recebida: ${message.messageId}');
    
    try {
      // Extrair dados da notificação
      final notification = _parseRemoteMessage(message);
      
      // Adicionar à lista local
      await _addNotification(notification);
      
      // Emitir evento
      _notificationController.add(notification);
      
      // Mostrar notificação local
      await _showLocalNotification(
        notification.id,
        notification.title,
        notification.message,
        notification.data,
      );
    } catch (e) {
      debugPrint('Erro ao processar mensagem em primeiro plano: $e');
    }
  }
  
  /// Manipula evento de toque em notificação quando o app está em background.
  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    debugPrint('Notificação em background tocada: ${message.messageId}');
    
    try {
      // Extrair dados da notificação
      final notification = _parseRemoteMessage(message);
      
      // Adicionar à lista local se não existir
      await _addNotification(notification);
      
      // Marcar como lida
      await markAsRead(notification.id);
      
      // Emitir evento
      _notificationController.add(notification);
      
      // TODO: Navegar para a tela apropriada com base nos dados da notificação
    } catch (e) {
      debugPrint('Erro ao processar toque em notificação: $e');
    }
  }
  
  /// Manipula mensagem inicial (quando o app é aberto a partir de uma notificação).
  static Future<void> _handleInitialMessage(RemoteMessage message) async {
    debugPrint('Mensagem inicial recebida: ${message.messageId}');
    
    try {
      // Extrair dados da notificação
      final notification = _parseRemoteMessage(message);
      
      // Adicionar à lista local se não existir
      await _addNotification(notification);
      
      // Marcar como lida
      await markAsRead(notification.id);
      
      // Emitir evento
      _notificationController.add(notification);
      
      // TODO: Navegar para a tela apropriada com base nos dados da notificação
    } catch (e) {
      debugPrint('Erro ao processar mensagem inicial: $e');
    }
  }
  
  /// Manipula evento de toque em notificação local.
  static void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('Notificação local tocada: ${response.id}');
    
    try {
      // Buscar notificação pelo ID
      final notificationId = int.tryParse(response.id ?? '0') ?? 0;
      final notification = _findNotificationById(notificationId);
      
      if (notification != null) {
        // Marcar como lida
        markAsRead(notification.id);
        
        // Emitir evento
        _notificationController.add(notification);
        
        // TODO: Navegar para a tela apropriada com base nos dados da notificação
      }
    } catch (e) {
      debugPrint('Erro ao processar toque em notificação local: $e');
    }
  }
  
  /// Converte uma mensagem remota para o modelo de notificação do app.
  static app.Notification _parseRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    final data = message.data;
    
    final title = notification?.title ?? data['title'] ?? 'Nova notificação';
    final body = notification?.body ?? data['message'] ?? data['body'] ?? '';
    
    // Extrair tipo e dados adicionais
    final type = data['type'] ?? 'general';
    Map<String, dynamic> additionalData = {};
    
    try {
      // Tentar extrair dados JSON
      if (data['data'] != null) {
        if (data['data'] is String) {
          additionalData = jsonDecode(data['data']);
        } else if (data['data'] is Map) {
          additionalData = Map<String, dynamic>.from(data['data']);
        }
      } else {
        // Copiar dados para additionalData, excluindo campos padrão
        data.forEach((key, value) {
          if (!['title', 'message', 'body', 'type', 'id'].contains(key)) {
            additionalData[key] = value;
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao processar dados adicionais: $e');
    }
    
    return app.Notification(
      id: int.tryParse(data['id'] ?? '${DateTime.now().millisecondsSinceEpoch}') ??
          DateTime.now().millisecondsSinceEpoch,
      title: title,
      message: body,
      type: type,
      data: additionalData,
      timestamp: DateTime.now(),
      read: false,
    );
  }
  
  /// Mostra uma notificação local.
  static Future<void> _showLocalNotification(
    int id,
    String title,
    String body,
    Map<String, dynamic>? payload,
  ) async {
    try {
      // Configurações para Android
      const androidDetails = AndroidNotificationDetails(
        'ceriv_notifications',
        'CER IV Notificações',
        channelDescription: 'Canal para notificações do CER IV',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      
      // Configurações para iOS
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      // Configurações gerais
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Payload como string JSON
      final payloadString = payload != null ? jsonEncode(payload) : null;
      
      // Mostrar notificação
      await _flutterLocalNotifications.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payloadString,
      );
    } catch (e) {
      debugPrint('Erro ao mostrar notificação local: $e');
    }
  }
  
  /// Carrega notificações salvas.
  static Future<void> _loadNotifications() async {
    try {
      final json = await _storageService.getString(_notificationsKey);
      
      if (json != null && json.isNotEmpty) {
        final List<dynamic> list = jsonDecode(json);
        _notifications = list
          .map((item) => app.Notification.fromMap(item))
          .toList();
        
        // Ordenar por timestamp (mais recente primeiro)
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        // Emitir lista atualizada
        _notificationsListController.add(_notifications);
        
        debugPrint('Notificações carregadas: ${_notifications.length}');
      } else {
        _notifications = [];
        _notificationsListController.add(_notifications);
      }
    } catch (e) {
      debugPrint('Erro ao carregar notificações: $e');
      _notifications = [];
      _notificationsListController.add(_notifications);
    }
  }
  
  /// Salva notificações no armazenamento local.
  static Future<void> _saveNotifications() async {
    try {
      final json = jsonEncode(_notifications.map((n) => n.toMap()).toList());
      await _storageService.setString(_notificationsKey, json);
    } catch (e) {
      debugPrint('Erro ao salvar notificações: $e');
    }
  }
  
  /// Adiciona uma notificação à lista local.
  static Future<void> _addNotification(app.Notification notification) async {
    try {
      // Verificar se já existe
      final existingIndex = _notifications
        .indexWhere((n) => n.id == notification.id);
      
      if (existingIndex >= 0) {
        // Atualizar notificação existente
        _notifications[existingIndex] = notification;
      } else {
        // Adicionar nova notificação
        _notifications.add(notification);
        
        // Ordenar por timestamp (mais recente primeiro)
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        // Limitar número de notificações (manter apenas as 100 mais recentes)
        if (_notifications.length > 100) {
          _notifications = _notifications.sublist(0, 100);
        }
      }
      
      // Salvar notificações
      await _saveNotifications();
      
      // Emitir lista atualizada
      _notificationsListController.add(_notifications);
    } catch (e) {
      debugPrint('Erro ao adicionar notificação: $e');
    }
  }
  
  /// Busca uma notificação pelo ID.
  static app.Notification? _findNotificationById(int id) {
    try {
      return _notifications.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Marca uma notificação como lida.
  static Future<void> markAsRead(int id) async {
    try {
      // Buscar notificação
      final index = _notifications.indexWhere((n) => n.id == id);
      
      if (index >= 0) {
        // Marcar como lida localmente
        _notifications[index] = _notifications[index].copyWith(read: true);
        
        // Salvar notificações
        await _saveNotifications();
        
        // Emitir lista atualizada
        _notificationsListController.add(_notifications);
        
        // Atualizar no servidor
        await _apiService.put(
          '/api/notifications/$id/read',
          data: {'read': true},
        );
      }
    } catch (e) {
      debugPrint('Erro ao marcar notificação como lida: $e');
    }
  }
  
  /// Marca todas as notificações como lidas.
  static Future<void> markAllAsRead() async {
    try {
      // Marcar todas como lidas localmente
      _notifications = _notifications
        .map((n) => n.copyWith(read: true))
        .toList();
      
      // Salvar notificações
      await _saveNotifications();
      
      // Emitir lista atualizada
      _notificationsListController.add(_notifications);
      
      // Atualizar no servidor
      await _apiService.put(
        '/api/notifications/mark_all_read',
        data: {},
      );
    } catch (e) {
      debugPrint('Erro ao marcar todas notificações como lidas: $e');
    }
  }
  
  /// Exclui uma notificação.
  static Future<void> deleteNotification(int id) async {
    try {
      // Remover localmente
      _notifications.removeWhere((n) => n.id == id);
      
      // Salvar notificações
      await _saveNotifications();
      
      // Emitir lista atualizada
      _notificationsListController.add(_notifications);
      
      // Atualizar no servidor
      await _apiService.delete(
        '/api/notifications/$id',
      );
    } catch (e) {
      debugPrint('Erro ao excluir notificação: $e');
    }
  }
  
  /// Limpa todas as notificações.
  static Future<void> clearAllNotifications() async {
    try {
      // Limpar localmente
      _notifications.clear();
      
      // Salvar notificações
      await _saveNotifications();
      
      // Emitir lista atualizada
      _notificationsListController.add(_notifications);
      
      // Atualizar no servidor
      await _apiService.delete(
        '/api/notifications/clear_all',
      );
    } catch (e) {
      debugPrint('Erro ao limpar notificações: $e');
    }
  }
  
  /// Retorna a lista de notificações.
  static List<app.Notification> get notifications => _notifications;
  
  /// Retorna o número de notificações não lidas.
  static int get unreadCount => _notifications.where((n) => !n.read).length;
  
  /// Obtém o token FCM para notificações push.
  static Future<String?> getFcmToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('Erro ao obter token FCM: $e');
      return null;
    }
  }
  
  /// Envia uma notificação local.
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Criar notificação
      final notification = app.Notification(
        id: DateTime.now().millisecondsSinceEpoch,
        title: title,
        message: body,
        type: 'local',
        data: data ?? {},
        timestamp: DateTime.now(),
        read: false,
      );
      
      // Adicionar à lista local
      await _addNotification(notification);
      
      // Emitir evento
      _notificationController.add(notification);
      
      // Mostrar notificação local
      await _showLocalNotification(
        notification.id,
        notification.title,
        notification.message,
        notification.data,
      );
    } catch (e) {
      debugPrint('Erro ao mostrar notificação local: $e');
    }
  }
  
  /// Encerra o serviço.
  static void dispose() {
    _notificationController.close();
    _notificationsListController.close();
  }
}