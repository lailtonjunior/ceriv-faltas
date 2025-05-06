// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:ceriv_app/routes.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'João Silva',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                Text(
                  'joao.silva@example.com',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Início'),
            onTap: () {
              Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('Registrar Presença'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.qrScan);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Histórico de Presenças'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.history);
            },
          ),
          ListTile(
            leading: const Icon(Icons.note_add),
            title: const Text('Justificar Ausência'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.justification);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Meu Perfil'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppRoutes.profile);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurações'),
            onTap: () {
              Navigator.pop(context);
              // Implementar configurações
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recurso em implementação'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Ajuda e Suporte'),
            onTap: () {
              Navigator.pop(context);
              // Implementar ajuda e suporte
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recurso em implementação'),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.red),
            title: const Text('Sair', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
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