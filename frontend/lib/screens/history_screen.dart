// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:ceriv_app/routes.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _months = ['Maio', 'Abril', 'Março', 'Fevereiro', 'Janeiro'];
  String _selectedMonth = 'Maio';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Presenças'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'TODAS'),
            Tab(text: 'PRESENTES'),
            Tab(text: 'AUSENTES'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtrar por mês:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedMonth,
                  items: _months.map((String month) {
                    return DropdownMenuItem<String>(
                      value: month,
                      child: Text(month),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedMonth = newValue;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                PresenceList(status: 'all'),
                PresenceList(status: 'present'),
                PresenceList(status: 'absent'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PresenceList extends StatelessWidget {
  final String status;

  const PresenceList({Key? key, required this.status}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> items = [];

    // Simulação de dados para a listagem
    for (int i = 1; i <= 20; i++) {
      final bool isPresent = i % 3 != 0;
      final bool isJustified = i % 5 == 0;

      // Filtrar de acordo com o status selecionado
      if (status == 'present' && !isPresent) continue;
      if (status == 'absent' && isPresent) continue;

      items.add({
        'id': i,
        'date': '${i < 10 ? "0$i" : i}/05/2025',
        'time': '19:00 - 22:30',
        'subject': 'Desenvolvimento Mobile',
        'isPresent': isPresent,
        'isJustified': isJustified,
      });
    }

    if (items.isEmpty) {
      return const Center(
        child: Text('Nenhum registro encontrado'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Aula ${item['id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item['isPresent']
                            ? Colors.green.withOpacity(0.2)
                            : item['isJustified']
                                ? Colors.amber.withOpacity(0.2)
                                : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item['isPresent']
                            ? 'Presente'
                            : item['isJustified']
                                ? 'Justificada'
                                : 'Ausente',
                        style: TextStyle(
                          color: item['isPresent']
                              ? Colors.green
                              : item['isJustified']
                                  ? Colors.amber
                                  : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item['subject'],
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Data: ${item['date']}',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Horário: ${item['time']}',
                      style: TextStyle(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (!item['isPresent'] && !item['isJustified'])
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.justification);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Text('Justificar Ausência'),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}