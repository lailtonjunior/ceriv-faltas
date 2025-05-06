import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Representa um badge (conquista) no sistema de gamificação
class Badge extends Equatable {
  /// Identificador único do badge
  final String id;
  
  /// Nome/título do badge
  final String title;
  
  /// Descrição do badge
  final String description;
  
  /// URL da imagem do badge
  final String? imageUrl;
  
  /// Categoria do badge (ex: attendance, progress, engagement)
  final String category;
  
  /// Tipo de ícone (para exibição na UI quando não há imagem)
  final String? iconType;
  
  /// Cor do badge (em hexadecimal)
  final String? colorHex;
  
  /// Número de pontos que o badge concede
  final int points;
  
  /// Nível de dificuldade (1-5)
  final int level;
  
  /// Ordem de exibição na lista
  final int order;
  
  /// Condição para conquistar o badge (texto explicativo)
  final String condition;
  
  /// Dica para ajudar a conquistar o badge
  final String? hint;
  
  /// Flag indicando se o badge foi conquistado pelo usuário
  final bool isEarned;
  
  /// Data em que o badge foi conquistado (se aplicável)
  final DateTime? earnedAt;
  
  /// Dados adicionais em formato JSON
  final Map<String, dynamic>? metadata;
  
  const Badge({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.category,
    this.iconType,
    this.colorHex,
    required this.points,
    required this.level,
    required this.order,
    required this.condition,
    this.hint,
    this.isEarned = false,
    this.earnedAt,
    this.metadata,
  });
  
  /// Obtém o ícone correspondente ao tipo, ou um padrão
  IconData getIcon() {
    switch (iconType) {
      case 'trophy':
        return Icons.emoji_events;
      case 'star':
        return Icons.star;
      case 'calendar':
        return Icons.calendar_today;
      case 'clock':
        return Icons.timer;
      case 'check':
        return Icons.check_circle;
      case 'medal':
        return Icons.military_tech;
      case 'target':
        return Icons.track_changes;
      case 'rocket':
        return Icons.rocket_launch;
      case 'flag':
        return Icons.flag;
      case 'heart':
        return Icons.favorite;
      default:
        return Icons.emoji_events; // Ícone padrão
    }
  }
  
  /// Obtém a cor do badge, ou uma cor padrão
  Color getColor() {
    if (colorHex != null && colorHex!.isNotEmpty) {
      try {
        final hexCode = colorHex!.replaceAll('#', '');
        return Color(int.parse('0xFF$hexCode'));
      } catch (e) {
        // Ignorar erro e usar cor padrão
      }
    }
    
    // Cores padrão por categoria
    switch (category) {
      case 'attendance':
        return Colors.blue;
      case 'progress':
        return Colors.green;
      case 'engagement':
        return Colors.orange;
      case 'special':
        return Colors.purple;
      default:
        return Colors.teal;
    }
  }
  
  /// Obtém um texto descritivo para a categoria
  String getCategoryText() {
    switch (category) {
      case 'attendance':
        return 'Presença';
      case 'progress':
        return 'Progresso';
      case 'engagement':
        return 'Engajamento';
      case 'special':
        return 'Especial';
      default:
        return category;
    }
  }
  
  /// Obtém uma representação textual do nível de dificuldade
  String getLevelText() {
    switch (level) {
      case 1:
        return 'Fácil';
      case 2:
        return 'Básico';
      case 3:
        return 'Intermediário';
      case 4:
        return 'Avançado';
      case 5:
        return 'Especialista';
      default:
        return 'Nível $level';
    }
  }
  
  /// Cria uma instância a partir de JSON
  factory Badge.fromJson(Map<String, dynamic> json) {
    return Badge(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imageUrl: json['image_url'],
      category: json['category'],
      iconType: json['icon_type'],
      colorHex: json['color_hex'],
      points: json['points'] ?? 0,
      level: json['level'] ?? 1,
      order: json['order'] ?? 0,
      condition: json['condition'] ?? 'Condição não especificada',
      hint: json['hint'],
      isEarned: json['is_earned'] ?? false,
      earnedAt: json['earned_at'] != null ? DateTime.parse(json['earned_at']) : null,
      metadata: json['metadata'] != null 
          ? Map<String, dynamic>.from(json['metadata']) 
          : null,
    );
  }
  
  /// Converte para formato JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'category': category,
      'icon_type': iconType,
      'color_hex': colorHex,
      'points': points,
      'level': level,
      'order': order,
      'condition': condition,
      'hint': hint,
      'is_earned': isEarned,
      'earned_at': earnedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  /// Cria uma cópia com modificações
  Badge copyWith({
    String? id,
    String? title,
    String? description,
    String? imageUrl,
    String? category,
    String? iconType,
    String? colorHex,
    int? points,
    int? level,
    int? order,
    String? condition,
    String? hint,
    bool? isEarned,
    DateTime? earnedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Badge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      iconType: iconType ?? this.iconType,
      colorHex: colorHex ?? this.colorHex,
      points: points ?? this.points,
      level: level ?? this.level,
      order: order ?? this.order,
      condition: condition ?? this.condition,
      hint: hint ?? this.hint,
      isEarned: isEarned ?? this.isEarned,
      earnedAt: earnedAt ?? this.earnedAt,
      metadata: metadata ?? this.metadata,
    );
  }
  
  @override
  List<Object?> get props => [
    id,
    title,
    description,
    imageUrl,
    category,
    iconType,
    colorHex,
    points,
    level,
    order,
    condition,
    hint,
    isEarned,
    earnedAt,
    metadata,
  ];
}