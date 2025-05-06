// lib/blocs/theme/theme_event.dart
import 'package:equatable/equatable.dart';

abstract class ThemeEvent extends Equatable {
  const ThemeEvent();

  @override
  List<Object> get props => [];
}

class InitThemeEvent extends ThemeEvent {}

class SetDarkThemeEvent extends ThemeEvent {}

class SetLightThemeEvent extends ThemeEvent {}