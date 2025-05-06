import 'dart:convert';

class Notification {
  final int id;
  final String title;
  final String message;
  final String type;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime? readAt;
  final DateTime timestamp;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    Map<String, dynamic>? data,
    this.read = false,
    this.readAt,
    DateTime? timestamp,
  }) : 
    this.data = data ?? {},
    this.timestamp = timestamp ?? DateTime.now();

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'] as int,
      title: map['title'] as String,
      message: map['message'] as String,
      type: map['type'] as String,
      data: map['data'] != null ? 
          Map<String, dynamic>.from(map['data'] as Map) : 
          {},
      read: map['read'] as bool? ?? false,
      readAt: map['read_at'] != null ? 
          DateTime.parse(map['read_at'] as String) : 
          null,
      timestamp: map['timestamp'] != null ? 
          DateTime.parse(map['timestamp'] as String) : 
          map['created_at'] != null ? 
              DateTime.parse(map['created_at'] as String) : 
              DateTime.now(),
    );
  }

  factory Notification.fromJson(String source) => 
      Notification.fromMap(json.decode(source) as Map<String, dynamic>);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'data': data,
      'read': read,
      'read_at': readAt?.toIso8601String(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  Notification copyWith({
    int? id,
    String? title,
    String? message,
    String? type,
    Map<String, dynamic>? data,
    bool? read,
    DateTime? readAt,
    DateTime? timestamp,
  }) {
    return Notification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      data: data ?? this.data,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'Notification(id: $id, title: $title, type: $type, read: $read)';
  }

  // Helpers para identificar tipos de notificação
  bool get isAppointment => type == 'appointment';
  bool get isAbsence => type == 'absence';
  bool get isBadge => type == 'badge';
  bool get isSystem => type == 'system';
  
  // Helper para obter o ícone apropriado para o tipo
  IconData get icon {
    switch (type) {
      case 'appointment':
        return Icons.event;
      case 'absence':
        return Icons.warning;
      case 'badge':
        return Icons.emoji_events;
      case 'system':
        return Icons.info;
      case 'message':
        return Icons.chat;
      default:
        return Icons.notifications;
    }
  }
}

// Importação necessária para o IconData
import 'package:flutter/material.dart';