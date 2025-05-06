import 'dart:convert';
import 'package:ceriv_app/models/message.dart';

class Conversation {
  final String id;
  final int patientId;
  final int? staffId;
  final String patientName;
  final String? staffName;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final Message? lastMessage;
  final bool isActive;

  Conversation({
    required this.id,
    required this.patientId,
    this.staffId,
    required this.patientName,
    this.staffName,
    required this.createdAt,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.lastMessage,
    this.isActive = true,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      patientId: map['patient_id'] as int,
      staffId: map['staff_id'] as int?,
      patientName: map['patient_name'] as String,
      staffName: map['staff_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      lastMessageAt: map['last_message_at'] != null
          ? DateTime.parse(map['last_message_at'] as String)
          : null,
      unreadCount: map['unread_count'] as int? ?? 0,
      lastMessage: map['last_message'] != null
          ? Message.fromMap(map['last_message'] as Map<String, dynamic>)
          : null,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patient_id': patientId,
      'staff_id': staffId,
      'patient_name': patientName,
      'staff_name': staffName,
      'created_at': createdAt.toIso8601String(),
      'last_message_at': lastMessageAt?.toIso8601String(),
      'unread_count': unreadCount,
      'last_message': lastMessage?.toMap(),
      'is_active': isActive,
    };
  }

  String toJson() => json.encode(toMap());

  factory Conversation.fromJson(String source) =>
      Conversation.fromMap(json.decode(source) as Map<String, dynamic>);

  Conversation copyWith({
    String? id,
    int? patientId,
    int? staffId,
    String? patientName,
    String? staffName,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    int? unreadCount,
    Message? lastMessage,
    bool? isActive,
  }) {
    return Conversation(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      staffId: staffId ?? this.staffId,
      patientName: patientName ?? this.patientName,
      staffName: staffName ?? this.staffName,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() {
    return 'Conversation(id: $id, patientName: $patientName, staffName: $staffName, unreadCount: $unreadCount)';
  }
}