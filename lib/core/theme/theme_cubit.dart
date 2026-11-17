import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Controls light/dark/system Material 3 theme mode.
class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({ThemeMode initialMode = ThemeMode.system}) : super(initialMode);

  void setThemeMode(ThemeMode mode) => emit(mode);

  void toggleLightDark() {
    emit(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }
}
