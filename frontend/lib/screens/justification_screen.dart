// lib/screens/justification_screen.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:ceriv_app/routes.dart';

class JustificationScreen extends StatefulWidget {
  const JustificationScreen({Key? key}) : super(key: key);

  @override
  State<JustificationScreen> createState() => _JustificationScreenState();
}

class _JustificationScreenState extends State<JustificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedReason;
  bool _isSubmitting = false;
  File? _attachedFile;

  final List<String> _reasonOptions = [
    'Problema de saúde',
    'Compromisso de trabalho',
    'Problemas familiares',
    'Transporte/locomoção',
    'Outro'
  ];

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      // Simulando o envio
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _isSubmitting = false;
        });
        _showSuccessDialog();
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Justificativa Enviada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Sua justificativa foi enviada com sucesso!',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'A coordenação irá analisar e responder em breve.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
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

  void _attachDocument() {
    // Simulando a anexação de um documento
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Documento anexado com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
    setState(() {
      _attachedFile = File('documento.pdf');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Justificar Ausência'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preencha o formulário abaixo para justificar sua ausência:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Data da Ausência',
                      prefixIcon: Icon(Icons.calendar_today),
                      border: OutlineInputBorder(),
                    ),
                    controller: TextEditingController(
                      text:
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, selecione uma data';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Motivo da Ausência',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                value: _selectedReason,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, selecione o motivo da ausência';
                  }
                  return null;
                },
                items: _reasonOptions.map((String reason) {
                  return DropdownMenuItem<String>(
                    value: reason,
                    child: Text(reason),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedReason = newValue;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Descrição Detalhada',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, forneça uma descrição';
                  }
                  if (value.length < 20) {
                    return 'A descrição deve ter pelo menos 20 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Documentos Comprobatórios',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Anexe documentos que comprovem o motivo da ausência (atestados, declarações, etc.)',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _attachDocument,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('ANEXAR DOCUMENTO'),
                    ),
                  ),
                ],
              ),
              if (_attachedFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.description, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _attachedFile!.path.split('/').last,
                          style: const TextStyle(color: Colors.green),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _attachedFile = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('ENVIAR JUSTIFICATIVA'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}