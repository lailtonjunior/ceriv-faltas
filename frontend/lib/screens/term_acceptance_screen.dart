import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ceriv_app/models/term.dart';
import 'package:ceriv_app/repositories/term_repository.dart';
import 'package:ceriv_app/services/service_locator.dart';
import 'package:ceriv_app/theme.dart';
import 'package:ceriv_app/widgets/custom_button.dart';
import 'package:ceriv_app/widgets/custom_card.dart';
import 'package:ceriv_app/widgets/offline_banner.dart';
import 'package:ceriv_app/blocs/connectivity/connectivity_bloc.dart';

class TermAcceptanceScreen extends StatefulWidget {
  final bool isOnboarding;

  const TermAcceptanceScreen({
    Key? key,
    this.isOnboarding = false,
  }) : super(key: key);

  @override
  State<TermAcceptanceScreen> createState() => _TermAcceptanceScreenState();
}

class _TermAcceptanceScreenState extends State<TermAcceptanceScreen> {
  final TermRepository _termRepository = getIt<TermRepository>();
  
  List<Term> _terms = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadTerms();
  }
  
  Future<void> _loadTerms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final response = await _termRepository.getTerms();
      
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.data != null) {
          _terms = response.data!;
        } else {
          _errorMessage = response.error?.message ?? 'Erro ao carregar termos';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar termos: $e';
      });
    }
  }
  
  Future<void> _acceptTerm(Term term) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await _termRepository.acceptTerm(term.id);
      
      setState(() {
        _isLoading = false;
        if (response.isSuccess) {
          // Atualizar o estado local do termo
          final index = _terms.indexOf(term);
          if (index != -1) {
            _terms[index] = term.copyWith(isAccepted: true);
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${term.title} aceito com sucesso')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error?.message ?? 'Erro ao aceitar termo'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao aceitar termo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  bool _allRequiredTermsAccepted() {
    final requiredTerms = _terms.where((term) => term.isRequired);
    return requiredTerms.every((term) => term.isAccepted);
  }
  
  void _continueOnboarding() {
    if (_allRequiredTermsAccepted()) {
      // Navegar para a próxima tela no fluxo de onboarding
      Navigator.of(context).pushReplacementNamed('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('É necessário aceitar todos os termos obrigatórios para continuar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos de Uso'),
        automaticallyImplyLeading: !widget.isOnboarding,
      ),
      body: Stack(
        children: [
          // Conteúdo principal
          RefreshIndicator(
            onRefresh: _loadTerms,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: _buildContent(),
            ),
          ),
          
          // Banner de offline
          BlocBuilder<ConnectivityBloc, ConnectivityState>(
            builder: (context, state) {
              if (state is ConnectivityOffline) {
                return const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: OfflineBanner(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      bottomNavigationBar: widget.isOnboarding
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: CustomButton(
                text: 'Continuar',
                onPressed: _continueOnboarding,
                variant: ButtonVariant.primary,
                isEnabled: _allRequiredTermsAccepted(),
              ),
            )
          : null,
    );
  }
  
  Widget _buildContent() {
    if (_isLoading) {
      return SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'Tentar novamente',
                onPressed: _loadTerms,
                variant: ButtonVariant.primary,
                isFullWidth: false,
              ),
            ],
          ),
        ),
      );
    }
    
    if (_terms.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height - 200,
        child: const Center(
          child: Text(
            'Nenhum termo disponível',
            style: TextStyle(color: AppTheme.mediumGrey),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Termos e Condições',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Revise e aceite nossos termos de uso para continuar utilizando o aplicativo.',
          style: TextStyle(color: AppTheme.mediumGrey),
        ),
        const SizedBox(height: 24),
        
        // Lista de termos
        ..._terms.map((term) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: CustomCard(
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    term.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (term.isRequired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Obrigatório',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Conteúdo do termo (limitado para não ficar muito grande)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(term.content),
                    ),
                  ),
                ),
                const Divider(),
                
                // Status e botão para aceitar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          term.isAccepted
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: term.isAccepted
                              ? Colors.green
                              : AppTheme.mediumGrey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          term.isAccepted
                              ? 'Aceito em ${_formatDate(term.updatedAt)}'
                              : 'Não aceito',
                          style: TextStyle(
                            color: term.isAccepted
                                ? Colors.green
                                : AppTheme.mediumGrey,
                          ),
                        ),
                      ],
                    ),
                    if (!term.isAccepted)
                      OutlinedButton(
                        onPressed: () => _acceptTerm(term),
                        child: const Text('Aceitar'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    
    return '$day/$month/$year';
  }
}