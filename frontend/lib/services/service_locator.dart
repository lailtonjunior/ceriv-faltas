import 'package:get_it/get_it.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:ceriv_app/services/api_service.dart';
import 'package:ceriv_app/services/storage_service.dart';
import 'package:ceriv_app/services/auth_service.dart';
import 'package:ceriv_app/services/offline_queue_service.dart';

import 'package:ceriv_app/repositories/patient_repository.dart';
import 'package:ceriv_app/repositories/term_repository.dart';
import 'package:ceriv_app/repositories/presence_repository.dart';
import 'package:ceriv_app/repositories/badge_repository.dart';

import 'package:ceriv_app/blocs/auth/auth_bloc.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Serviços
  final storageService = StorageService();
  await storageService.init();
  getIt.registerSingleton<StorageService>(storageService);

  getIt.registerLazySingleton<ApiService>(() => ApiService(
        baseUrl: 'https://api.ceriv.com.br',
        storageService: getIt<StorageService>(),
        authService: getIt<AuthService>(),
      ));

  getIt.registerLazySingleton<AuthService>(() => AuthService(
        storageService: getIt<StorageService>(),
        apiService: getIt<ApiService>(),
      ));

  getIt.registerLazySingleton<OfflineQueueService>(() => OfflineQueueService(
        apiService: getIt<ApiService>(),
        storageService: getIt<StorageService>(),
      ));

  // Repositórios
  getIt.registerLazySingleton<PatientRepository>(() => PatientRepository(
        apiService: getIt<ApiService>(),
        storageService: getIt<StorageService>(),
      ));

  getIt.registerLazySingleton<TermRepository>(() => TermRepository(
        apiService: getIt<ApiService>(),
        storageService: getIt<StorageService>(),
      ));

  getIt.registerLazySingleton<PresenceRepository>(() => PresenceRepository(
        apiService: getIt<ApiService>(),
        storageService: getIt<StorageService>(),
      ));

  getIt.registerLazySingleton<BadgeRepository>(() => BadgeRepository(
        apiService: getIt<ApiService>(),
        storageService: getIt<StorageService>(),
      ));

  // Blocs
  getIt.registerFactory<AuthBloc>(() => AuthBloc(
        authService: getIt<AuthService>(),
      ));

  // Inicializa serviços
  await getIt<OfflineQueueService>().init();
}