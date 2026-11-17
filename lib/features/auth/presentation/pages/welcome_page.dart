import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ledgerflow_flutter/features/auth/presentation/cubit/auth_cubit.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitCloudAuth() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final cubit = context.read<AuthCubit>();
    if (_isSignUp) {
      cubit.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      cubit.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final isSupabaseConfigured =
        context.read<AuthCubit>().isSupabaseConfigured;

    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
            }
          },
          builder: (context, state) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  24 + viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.account_balance_wallet,
                            size: 34,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'LedgerFlow',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Offline-first personal & group expense ledger backed by SQLite and transactional outbox sync.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        key: const Key('guest_mode_button'),
                        onPressed: state.isSubmitting
                            ? null
                            : () => context.read<AuthCubit>().enterGuestMode(),
                        icon: const Icon(Icons.bolt_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Continue as Guest (30-Day Sample Data)'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Cloud Sync (Supabase)',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isSupabaseConfigured
                                      ? 'Sign in or create an account to sync across devices.'
                                      : 'Running standalone offline. Pass SUPABASE_URL & SUPABASE_ANON_KEY via --dart-define for live cloud sync.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  key: const Key('supabase_email_field'),
                                  controller: _emailController,
                                  enabled: isSupabaseConfigured &&
                                      !state.isSubmitting,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(Icons.email_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null || !value.contains('@')) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  key: const Key('supabase_password_field'),
                                  controller: _passwordController,
                                  enabled: isSupabaseConfigured &&
                                      !state.isSubmitting,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: Icon(Icons.lock_outline),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.length < 6) {
                                      return 'Minimum 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  key: const Key('supabase_signin_button'),
                                  onPressed: isSupabaseConfigured &&
                                          !state.isSubmitting
                                      ? _submitCloudAuth
                                      : null,
                                  child: Text(
                                    _isSignUp
                                        ? 'Create Cloud Account'
                                        : 'Sign In to Cloud',
                                  ),
                                ),
                                TextButton(
                                  onPressed: isSupabaseConfigured &&
                                          !state.isSubmitting
                                      ? () => setState(
                                            () => _isSignUp = !_isSignUp,
                                          )
                                      : null,
                                  child: Text(
                                    _isSignUp
                                        ? 'Already have an account? Sign In'
                                        : 'Need a cloud account? Sign Up',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
