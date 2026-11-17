import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/core/theme/theme_cubit.dart';

void main() {
  group('ThemeCubit', () {
    blocTest<ThemeCubit, ThemeMode>(
      'toggles between dark and light modes',
      build: () => ThemeCubit(initialMode: ThemeMode.light),
      act: (cubit) => cubit
        ..toggleLightDark()
        ..toggleLightDark(),
      expect: () => [ThemeMode.dark, ThemeMode.light],
    );

    blocTest<ThemeCubit, ThemeMode>(
      'sets explicit ThemeMode',
      build: ThemeCubit.new,
      act: (cubit) => cubit.setThemeMode(ThemeMode.dark),
      expect: () => [ThemeMode.dark],
    );
  });
}
