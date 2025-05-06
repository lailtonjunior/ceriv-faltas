import 'dart:convert';

class Message {
  final int id;
  final String conversationId;
  final int patientId;
  final int? userId;
  final String senderType;
  String content;
  final bool encrypted;
  bool read;
  DateTime? readAt;
  final String? attachmentUrl;
  final String? attachmentType;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.conversationId,
    required this.patientId,
    this.userId,
    required this.senderType,
    required this.content,
    this.encrypted = true,
    this.read = false,
    this.readAt,
    this.attachmentUrl,
    this.attachmentType,
    DateTime? timestamp,
  }) : this.timestamp = timestamp ?? DateTime.now();

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as int,
      conversationId: map['conversation_id'] as String,
      patientId: map['patient_id'] as int,
      userId: map['user_id'] as int?,
      senderType: map['sender_type'] as String,
      content: map['content'] as String,
      encrypted: map['encrypted'] as bool? ?? true,
      read: map['read'] as bool? ?? false,
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
      attachmentUrl: map['attachment_url'] as String?,
      attachmentType: map['attachment_type'] as String?,
      timestamp: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : map['timestamp'] != null
              ? DateTime.parse(map['timestamp'] as String)
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'patient_id': patientId,
      'user_id': userId,
      'sender_type': senderType,
      'content': content,
      'encrypted': encrypted,
      'read': read,
      'read_at': readAt?.toIso8601String(),
      'attachment_url': attachmentUrl,
      'attachment_type': attachmentType,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String toJson() => json.encode(toMap());

  factory Message.fromJson(String source) =>
      Message.fromMap(json.decode(source) as Map<String, dynamic>);

  Message copyWith({
    int? id,
    String? conversationId,
    int? patientId,
    int? userId,
    String? senderType,
    String? content,
    bool? encrypted,
    bool? read,
    DateTime? readAt,
    String? attachmentUrl,
    String? attachmentType,
    DateTime? timestamp,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      patientId: patientId ?? this.patientId,
      userId: userId ?? this.userId,
      senderType: senderType ?? this.senderType,
      content: content ?? this.content,
      encrypted: encrypted ?? this.encrypted,
      read: read ?? this.read,
      readAt: readAt ?? this.readAt,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, conversationId: $conversationId, senderType: $senderType, read: $read, timestamp: $timestamp)';
  }

  // Métodos auxiliares
  bool get isFromPatient => senderType == 'patient';
  bool get isFromStaff => senderType == 'staff';
  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImage => attachmentType == 'image';
  bool get isDocument => attachmentType == 'document' || attachmentType == 'pdf';
}