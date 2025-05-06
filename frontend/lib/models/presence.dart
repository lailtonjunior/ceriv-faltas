// lib/models/presence.dart
import 'package:equatable/equatable.dart';

class Presence extends Equatable {
  final String id;
  final String userId;
  final String status; // 'present', 'absent', 'justified'
  final String method; // 'qrcode', 'geolocation', 'manual'
  final DateTime date;
  final String? justification;
  final Map<String, dynamic>? metadata;

  const Presence({
    required this.id,
    required this.userId,
    required this.status,
    required this.method,
    required this.date,
    this.justification,
    this.metadata,
  });

  Presence copyWith({
    String? id,
    String? userId,
    String? status,
    String? method,
    DateTime? date,
    String? justification,
    Map<String, dynamic>? metadata,
  }) {
    return Presence(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      method: method ?? this.method,
      date: date ?? this.date,
      justification: justification ?? this.justification,
      metadata: metadata ?? this.metadata,
    );
  }

  factory Presence.fromJson(Map<String, dynamic> json) {
    return Presence(
      id: json['id'],
      userId: json['userId'],
      status: json['status'],
      method: json['method'],
      date: DateTime.parse(json['date']),
      justification: json['justification'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'status': status,
      'method': method,
      'date': date.toIso8601String(),
      'justification': justification,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [id, userId, status, method, date, justification, metadata];
}