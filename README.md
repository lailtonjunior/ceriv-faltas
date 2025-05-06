# CER IV App - Aplicativo para Centro Especializado em Reabilitação

Este é um aplicativo multiplataforma (Android / iOS / Web) para o Centro Especializado em Reabilitação (CER IV) que permite controlar presenças, faltas, notificações, termos digitais, chat seguro e gamificação dos pacientes.

## Funcionalidades

- Autenticação via Supabase Auth (e-mail + senha)
- Captura de presença por QR Code com geolocalização
- Chat em tempo real com criptografia ponta-a-ponta
- Gamificação (badges) e ranking privado
- Versionamento de termos (upload/geração de PDF)
- Integração com prontuário eletrônico
- Design System com tema claro/escuro

## Pré-requisitos

- Docker e Docker Compose
- Flutter SDK 3.x
- Dart 3.x
- PostgreSQL 16
- Conta no Supabase para autenticação
- Conta no SendGrid para envio de e-mails
- Firebase Cloud Messaging (FCM) para notificações push

## Configuração do Ambiente

### Backend (FastAPI)

1. Clone o repositório:
```bash
git clone https://github.com/seu-usuario/ceriv-app.git
cd ceriv-app
```

2. Configure as variáveis de ambiente:
```bash
cp .env.example .env
# Edite o arquivo .env com seus dados
```

3. Inicie o backend com Docker Compose:
```bash
docker compose up -d
```

4. O servidor FastAPI estará disponível em: http://localhost:8000
5. A documentação da API (Swagger) estará em: http://localhost:8000/docs

### Frontend (Flutter)

1. Entre na pasta do frontend:
```bash
cd frontend
```

2. Instale as dependências:
```bash
flutter pub get
```

3. Execute o aplicativo:
```bash
flutter run
```

## Estrutura do Banco de Dados

O aplicativo se integra ao banco PostgreSQL já utilizado no prontuário eletrônico. As principais tabelas são:

- `patients`: Informações dos pacientes
- `presences`: Registro de presenças
- `absence_rules`: Regras para faltas
- `badges`: Conquistas da gamificação
- `term_versions`: Versionamento dos termos de adesão
- `messages`: Mensagens do chat

## Migrations

Para executar as migrations do banco de dados:

```bash
cd backend
docker compose exec app alembic upgrade head
```

## Geração de APK/IPA para distribuição

### Android (APK)

```bash
cd frontend
flutter build apk --release
```
O APK será gerado em: `frontend/build/app/outputs/flutter-apk/app-release.apk`

### iOS (IPA)

```bash
cd frontend
flutter build ios --release
```
Após o build, abra o projeto no Xcode para gerar o arquivo IPA:
```bash
open build/ios/Runner.xcworkspace
```

## Próximos Passos

1. Implementar testes automatizados
2. Configurar CI/CD no GitHub Actions
3. Implementar autenticação via OAuth
4. Aprimorar a gamificação com mais badges e recompensas
5. Adicionar suporte a notificações mais avançadas
6. Implementar mais recursos de acessibilidade

## Suporte

Em caso de dúvidas ou problemas, abra uma issue no repositório do GitHub ou entre em contato com a equipe de desenvolvimento.