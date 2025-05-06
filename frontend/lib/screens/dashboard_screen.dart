// lib/screens/dashboard_screen.dart
// Substitua todo o conteúdo do arquivo por este código

import 'package:flutter/material.dart';
import 'package:ceriv_app/routes.dart';
import 'package:ceriv_app/widgets/app_drawer.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    HomeTab(),
    HistoryTab(),
    ProfileTab(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CERIV App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Implementar notificações
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: _widgetOptions.elementAt(_selectedIndex),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.qrScan);
        },
        child: const Icon(Icons.qr_code_scanner),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Início',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Histórico',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        onTap: _onItemTapped,
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumo de Presenças',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      StatItem(
                        title: 'Presentes',
                        value: '85%',
                        color: Colors.green,
                        icon: Icons.check_circle,
                      ),
                      StatItem(
                        title: 'Ausentes',
                        value: '10%',
                        color: Colors.red,
                        icon: Icons.cancel,
                      ),
                      StatItem(
                        title: 'Justificadas',
                        value: '5%',
                        color: Colors.amber,
                        icon: Icons.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Próxima Aula',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Segunda-feira, 06 de Maio de 2025',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      const Text('19:00 - 22:30'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      const Text('Sala 105, Bloco B'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Desenvolvimento Mobile com Flutter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('Prof. Ana Silva'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ações Rápidas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ActionCard(
                  title: 'Registrar Presença',
                  icon: Icons.qr_code_scanner,
                  color: Theme.of(context).primaryColor,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.qrScan);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ActionCard(
                  title: 'Justificar Ausência',
                  icon: Icons.note_add,
                  color: Colors.amber,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.justification);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ActionCard(
                  title: 'Ver Histórico',
                  icon: Icons.history,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.history);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ActionCard(
                  title: 'Editar Perfil',
                  icon: Icons.person,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HistoryTab extends StatelessWidget {
  const HistoryTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 10,
      itemBuilder: (context, index) {
        final isPresent = index % 3 != 0;
        final isJustified = index % 5 == 0;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPresent
                  ? Colors.green.withOpacity(0.2)
                  : isJustified
                      ? Colors.amber.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
              child: Icon(
                isPresent
                    ? Icons.check
                    : isJustified
                        ? Icons.assignment_late
                        : Icons.close,
                color: isPresent
                    ? Colors.green
                    : isJustified
                        ? Colors.amber
                        : Colors.red,
              ),
            ),
            title: Text(
              'Aula ${10 - index}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Data: ${30 - index}/04/2025 - Horário: 19:00',
            ),
            trailing: Text(
              isPresent
                  ? 'Presente'
                  : isJustified
                      ? 'Justificada'
                      : 'Ausente',
              style: TextStyle(
                color: isPresent
                    ? Colors.green
                    : isJustified
                        ? Colors.amber
                        : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey,
            child: Icon(
              Icons.person,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'João Silva',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'joao.silva@example.com',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Matrícula: 2023001234',
            style: TextStyle(fontSize: 16),
          ),
          const Text(
            'Curso: Engenharia de Software',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 32),
          ProfileMenuItem(
            icon: Icons.person,
            title: 'Editar Perfil',
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.profile);
            },
          ),
          const ProfileMenuItem(
            icon: Icons.notifications,
            title: 'Notificações',
            onTap: null,
          ),
          const ProfileMenuItem(
            icon: Icons.lock,
            title: 'Alterar Senha',
            onTap: null,
          ),
          const ProfileMenuItem(
            icon: Icons.help,
            title: 'Ajuda e Suporte',
            onTap: null,
          ),
          ProfileMenuItem(
            icon: Icons.exit_to_app,
            title: 'Sair',
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Sair da Conta'),
                    content: const Text('Tem certeza que deseja sair da conta?'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('CANCELAR'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.login,
                            (route) => false,
                          );
                        },
                        child: const Text('SAIR'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const StatItem({
    Key? key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 36,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const ActionCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const ProfileMenuItem({
    Key? key,
    required this.icon,
    required this.title,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}