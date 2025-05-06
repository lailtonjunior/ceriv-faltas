// lib/blocs/theme/theme_bloc.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ceriv_app/blocs/theme/theme_event.dart';
import 'package:ceriv_app/blocs/theme/theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(const ThemeState()) {
    on<InitThemeEvent>(_onInitTheme);
    on<SetDarkThemeEvent>(_onSetDarkTheme);
    on<SetLightThemeEvent>(_onSetLightTheme);
  }

  Future<void> _onInitTheme(InitThemeEvent event, Emitter<ThemeState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDarkMode = prefs.getBool('isDarkMode') ?? false;
      
      emit(state.copyWith(themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light));
    } catch (e) {
      // Se ocorrer algum erro, mantenha o tema padrão
      emit(state);
    }
  }

  Future<void> _onSetDarkTheme(SetDarkThemeEvent event, Emitter<ThemeState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', true);
      
      emit(state.copyWith(themeMode: ThemeMode.dark));
    } catch (e) {
      // Se ocorrer algum erro, apenas atualize o tema na memória
      emit(state.copyWith(themeMode: ThemeMode.dark));
    }
  }

  Future<void> _onSetLightTheme(SetLightThemeEvent event, Emitter<ThemeState> emit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', false);
      
      emit(state.copyWith(themeMode: ThemeMode.light));
    } catch (e) {
      // Se ocorrer algum erro, apenas atualize o tema na memória
      emit(state.copyWith(themeMode: ThemeMode.light));
    }
  }
}