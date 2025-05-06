import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Tipos de operações que podem ser armazenadas offline
enum OperationType {
  create,
  update,
  delete,
  custom,
}

/// Representa uma operação a ser realizada quando a conexão for restabelecida
class OfflineOperation extends Equatable {
  /// Identificador único da operação
  final String id;
  
  /// Tipo de operação (create, update, delete, custom)
  final OperationType type;
  
  /// Endpoint da API (sem a URL base)
  final String endpoint;
  
  /// Dados da requisição (para POST, PUT, etc.)
  final Map<String, dynamic>? data;
  
  /// Método HTTP (GET, POST, PUT, DELETE)
  final String method;
  
  /// Quando a operação foi criada
  final DateTime createdAt;
  
  /// Número de tentativas já realizadas
  final int attempts;
  
  /// Prioridade da operação (menor número = maior prioridade)
  final int priority;
  
  /// Identificador da entidade relacionada (se aplicável)
  final String? entityId;
  
  /// Tipo da entidade relacionada (se aplicável)
  final String? entityType;
  
  const OfflineOperation({
    required this.id,
    required this.type,
    required this.endpoint,
    this.data,
    required this.method,
    required this.createdAt,
    this.attempts = 0,
    this.priority = 5,  // Prioridade média por padrão
    this.entityId,
    this.entityType,
  });
  
  /// Construtor para criar uma nova operação
  factory OfflineOperation.create({
    required OperationType type,
    required String endpoint,
    Map<String, dynamic>? data,
    required String method,
    int priority = 5,
    String? entityId,
    String? entityType,
  }) {
    return OfflineOperation(
      id: const Uuid().v4(),
      type: type,
      endpoint: endpoint,
      data: data,
      method: method,
      createdAt: DateTime.now(),
      priority: priority,
      entityId: entityId,
      entityType: entityType,
    );
  }
  
  /// Incrementa o número de tentativas e retorna uma nova instância
  OfflineOperation incrementAttempts() {
    return copyWith(attempts: attempts + 1);
  }
  
  /// Cria uma cópia da operação com modificações
  OfflineOperation copyWith({
    String? id,
    OperationType? type,
    String? endpoint,
    Map<String, dynamic>? data,
    String? method,
    DateTime? createdAt,
    int? attempts,
    int? priority,
    String? entityId,
    String? entityType,
  }) {
    return OfflineOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      endpoint: endpoint ?? this.endpoint,
      data: data ?? this.data,
      method: method ?? this.method,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      priority: priority ?? this.priority,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
    );
  }
  
  /// Converte para formato JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'endpoint': endpoint,
      'data': data,
      'method': method,
      'createdAt': createdAt.toIso8601String(),
      'attempts': attempts,
      'priority': priority,
      'entityId': entityId,
      'entityType': entityType,
    };
  }
  
  /// Cria uma instância a partir de JSON
  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'],
      type: _parseOperationType(json['type']),
      endpoint: json['endpoint'],
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      method: json['method'],
      createdAt: DateTime.parse(json['createdAt']),
      attempts: json['attempts'] ?? 0,
      priority: json['priority'] ?? 5,
      entityId: json['entityId'],
      entityType: json['entityType'],
    );
  }
  
  /// Converte string para enum OperationType
  static OperationType _parseOperationType(String typeStr) {
    switch (typeStr) {
      case 'create':
        return OperationType.create;
      case 'update':
        return OperationType.update;
      case 'delete':
        return OperationType.delete;
      case 'custom':
        return OperationType.custom;
      default:
        return OperationType.custom;
    }
  }
  
  @override
  List<Object?> get props => [
    id,
    type,
    endpoint,
    data,
    method,
    createdAt,
    attempts,
    priority,
    entityId,
    entityType,
  ];