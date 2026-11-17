import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerflow_flutter/core/config/app_config.dart';

void main() {
  test('AppConfig.hasSupabaseConfig reflects presence of URL and key', () {
    const empty = AppConfig(supabaseUrl: '', supabaseAnonKey: '');
    expect(empty.hasSupabaseConfig, isFalse);

    const partial = AppConfig(
      supabaseUrl: 'https://demo.supabase.co',
      supabaseAnonKey: '   ',
    );
    expect(partial.hasSupabaseConfig, isFalse);

    const configured = AppConfig(
      supabaseUrl: 'https://demo.supabase.co',
      supabaseAnonKey: 'anon-key',
    );
    expect(configured.hasSupabaseConfig, isTrue);
  });
}
