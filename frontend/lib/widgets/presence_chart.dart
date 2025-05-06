// lib/widgets/presence_chart.dart
import 'package:flutter/material.dart';
import 'package:ceriv_app/models/presence.dart';
import 'package:ceriv_app/theme.dart';
import 'package:intl/intl.dart';

class PresenceChart extends StatelessWidget {
  final List<Presence> presences;

  const PresenceChart({
    Key? key,
    required this.presences,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Organizamos as presenças por mês para exibir no gráfico
    final presencesByMonth = _organizeByMonth(presences);
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Histórico de Presenças',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SimpleBarChart(data: presencesByMonth),
            ),
            const SizedBox(height: 16),
            _buildLegend(context),
          ],
        ),
      ),
    );
  }

  Map<String, Map<String, int>> _organizeByMonth(List<Presence> presences) {
    final result = <String, Map<String, int>>{};
    final formatter = DateFormat('MMM');
    
    for (final presence in presences) {
      final presenceDate = presence.date;
      final month = formatter.format(presenceDate);
      
      if (!result.containsKey(month)) {
        result[month] = {
          'present': 0,
          'absent': 0,
          'justified': 0,
        };
      }
      
      if (presence.status == 'present') {
        result[month]!['present'] = (result[month]!['present'] ?? 0) + 1;
      } else if (presence.status == 'absent') {
        result[month]!['absent'] = (result[month]!['absent'] ?? 0) + 1;
      } else if (presence.status == 'justified') {
        result[month]!['justified'] = (result[month]!['justified'] ?? 0) + 1;
      }
    }
    
    return result;
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(Colors.green, 'Presente'),
        const SizedBox(width: 16),
        _legendItem(Colors.red, 'Ausente'),
        const SizedBox(width: 16),
        _legendItem(Colors.amber, 'Justificado'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class SimpleBarChart extends StatelessWidget {
  final Map<String, Map<String, int>> data;

  const SimpleBarChart({
    Key? key,
    required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth / (data.length * 3 + (data.length - 1));
        final spacing = barWidth / 2;
        
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: (barWidth * 3 + spacing) * data.length,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final entry in data.entries) ...[
                  _buildBarGroup(
                    context,
                    entry.key,
                    entry.value,
                    barWidth,
                    constraints.maxHeight,
                  ),
                  if (entry.key != data.entries.last.key) 
                    SizedBox(width: spacing),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBarGroup(
    BuildContext context,
    String month,
    Map<String, int> values,
    double barWidth,
    double maxHeight,
  ) {
    final maxValue = values.values.fold(0, (a, b) => a > b ? a : b);
    final heightRatio = maxValue > 0 ? (maxHeight - 50) / maxValue : 0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(
              context,
              values['present'] ?? 0,
              barWidth,
              heightRatio,
              Colors.green,
            ),
            _buildBar(
              context,
              values['absent'] ?? 0,
              barWidth,
              heightRatio,
              Colors.red,
            ),
            _buildBar(
              context,
              values['justified'] ?? 0,
              barWidth,
              heightRatio,
              Colors.amber,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          month,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildBar(
    BuildContext context,
    int value,
    double width,
    double heightRatio,
    Color color,
  ) {
    final height = value * heightRatio;
    
    return Tooltip(
      message: value.toString(),
      child: Container(
        width: width,
        height: height > 0 ? height : 10,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: value > 0 ? color : Colors.grey[300],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ),
    );
  }
}