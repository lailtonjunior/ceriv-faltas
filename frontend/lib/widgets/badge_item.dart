import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ceriv_app/theme.dart';
import 'package:ceriv_app/models/badge.dart';

class BadgeItem extends StatelessWidget {
  final Badge badge;
  final VoidCallback? onTap;
  final bool showDate;
  final bool compact;

  const BadgeItem({
    Key? key,
    required this.badge,
    this.onTap,
    this.showDate = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: compact ? _buildCompactBadge(context) : _buildFullBadge(context),
    );
  }

  Widget _buildFullBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: _getBadgeColor(badge.category).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBadgeColor(badge.category).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Ícone ou imagem do badge
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _getBadgeColor(badge.category).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: badge.iconUrl != null && badge.iconUrl!.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.network(
                      badge.iconUrl!,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          _getBadgeIcon(badge.category),
                          color: _getBadgeColor(badge.category),
                          size: 24,
                        );
                      },
                    ),
                  )
                : Icon(
                    _getBadgeIcon(badge.category),
                    color: _getBadgeColor(badge.category),
                    size: 24,
                  ),
          ),
          const SizedBox(width: 12),
          // Informações do badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (badge.description != null && badge.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      badge.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.mediumGrey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (showDate && badge.awardedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Conquistado em ${_formatDate(badge.awardedAt!)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.mediumGrey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Pontuação
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getBadgeColor(badge.category),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${badge.points} pts',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getBadgeColor(badge.category).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getBadgeColor(badge.category).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Ícone ou imagem do badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getBadgeColor(badge.category).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: badge.iconUrl != null && badge.iconUrl!.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.network(
                      badge.iconUrl!,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          _getBadgeIcon(badge.category),
                          color: _getBadgeColor(badge.category),
                          size: 20,
                        );
                      },
                    ),
                  )
                : Icon(
                    _getBadgeIcon(badge.category),
                    color: _getBadgeColor(badge.category),
                    size: 20,
                  ),
          ),
          const SizedBox(width: 8),
          // Informações do badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  badge.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (showDate && badge.awardedAt != null)
                  Text(
                    _formatDate(badge.awardedAt!),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
              ],
            ),
          ),
          // Pontuação
          Text(
            '${badge.points}',
            style: TextStyle(
              color: _getBadgeColor(badge.category),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Color _getBadgeColor(String category) {
    switch (category.toLowerCase()) {
      case 'attendance':
      case 'assiduidade':
        return AppTheme.primaryColor;
      case 'progress':
      case 'progresso':
        return AppTheme.secondaryColor;
      case 'engagement':
      case 'participação':
      case 'participacao':
        return AppTheme.accentColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getBadgeIcon(String category) {
    switch (category.toLowerCase()) {
      case 'attendance':
      case 'assiduidade':
        return Icons.calendar_today;
      case 'progress':
      case 'progresso':
        return Icons.trending_up;
      case 'engagement':
      case 'participação':
      case 'participacao':
        return Icons.person;
      default:
        return Icons.emoji_events;
    }
  }
}