// lib/screens/qr_scan_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:ceriv_app/routes.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({Key? key}) : super(key: key);

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _isScanning = true;
  bool _scanSuccess = false;
  String _message = 'Posicione o QR Code dentro da área de leitura';

  @override
  void initState() {
    super.initState();
    _simulateScan();
  }

  void _simulateScan() {
    Timer(const Duration(seconds: 3), () {
      setState(() {
        _isScanning = false;
        _scanSuccess = true;
        _message = 'QR Code lido com sucesso!';
      });

      Timer(const Duration(seconds: 2), () {
        _showSuccessDialog();
      });
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Presença Registrada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text('Sua presença foi registrada com sucesso!'),
              const SizedBox(height: 8),
              Text(
                'Data: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              ),
              Text(
                'Hora: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR Code'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _scanSuccess ? Colors.green : Colors.white,
                          width: 2.0,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isScanning
                          ? const Center(
                              child: SizedBox(
                                width: 100,
                                height: 2,
                                child: LinearProgressIndicator(
                                  backgroundColor: Colors.transparent,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            )
                          : _scanSuccess
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 64,
                                )
                              : const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 64,
                                ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Dicas:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Certifique-se de que o QR Code está bem iluminado',
                  style: TextStyle(fontSize: 14),
                ),
                const Text(
                  '• Mantenha o celular firme durante a leitura',
                  style: TextStyle(fontSize: 14),
                ),
                const Text(
                  '• Posicione o QR Code inteiramente dentro do quadrado',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isScanning
                      ? null
                      : () {
                          setState(() {
                            _isScanning = true;
                            _scanSuccess = false;
                            _message =
                                'Posicione o QR Code dentro da área de leitura';
                          });
                          _simulateScan();
                        },
                  child: Text(_isScanning ? 'ESCANEANDO...' : 'TENTAR NOVAMENTE'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('CANCELAR'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}