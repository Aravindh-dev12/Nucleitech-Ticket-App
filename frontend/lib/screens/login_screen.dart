import 'package:flutter/material.dart';

import '../config.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ApiService.instance.login(
        _emailController.text,
        _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Unable to connect to the server.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 880;

            if (wide) {
              return Row(
                children: [
                  const Expanded(
                    flex: 5,
                    child: _BrandPanel(),
                  ),
                  Expanded(
                    flex: 6,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(42),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 470),
                          child: _SignInForm(
                            formKey: _formKey,
                            emailController: _emailController,
                            passwordController: _passwordController,
                            submitting: _submitting,
                            obscure: _obscure,
                            error: _error,
                            onTogglePassword: () =>
                                setState(() => _obscure = !_obscure),
                            onLogin: _login,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                const _MobileBrandHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 470),
                      child: _SignInForm(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        submitting: _submitting,
                        obscure: _obscure,
                        error: _error,
                        onTogglePassword: () =>
                            setState(() => _obscure = !_obscure),
                        onLogin: _login,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(54),
      color: const Color(0xFF0B5ED7),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BrandMark(size: 78),
          SizedBox(height: 28),
          Text(
            AppConfig.appName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.1,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Live SCADA monitoring and plant support tickets in one secure application.',
            style: TextStyle(
              color: Color(0xFFDCEAFF),
              fontSize: 18,
              height: 1.5,
            ),
          ),
          SizedBox(height: 38),
          _FeatureLine(
            icon: Icons.monitor_heart_outlined,
            text: 'Live plant, inverter and VCB overview',
          ),
          SizedBox(height: 16),
          _FeatureLine(
            icon: Icons.confirmation_number_outlined,
            text: 'Raise issues with images and track resolution',
          ),
          SizedBox(height: 16),
          _FeatureLine(
            icon: Icons.notifications_active_outlined,
            text: 'Automatic owner and customer notifications',
          ),
        ],
      ),
    );
  }
}

class _MobileBrandHeader extends StatelessWidget {
  const _MobileBrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 34),
      color: const Color(0xFF0B5ED7),
      child: const Column(
        children: [
          _BrandMark(size: 66),
          SizedBox(height: 16),
          Text(
            'NUCLEI TECH',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 27,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'SCADA & Ticket Management',
            style: TextStyle(
              color: Color(0xFFDCEAFF),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Icon(
        Icons.hub_outlined,
        color: const Color(0xFF0B5ED7),
        size: size * 0.56,
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.submitting,
    required this.obscure,
    required this.error,
    required this.onTogglePassword,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool submitting;
  final bool obscure;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Sign in',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF084298),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 7),
              Text(
                'Use your company or NUCLEI TECH owner account.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5B6B82),
                    ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email address.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: obscure,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => onLogin(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password.'
                    : null,
              ),
              if (error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF3B8B8)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFB42318),
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          error!,
                          style: const TextStyle(color: Color(0xFFB42318)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: submitting ? null : onLogin,
                icon: submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login),
                label: Text(submitting ? 'Signing in...' : 'Sign In'),
              ),
              const SizedBox(height: 18),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 17,
                    color: Color(0xFF5B6B82),
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Secure role-based access',
                    style: TextStyle(
                      color: Color(0xFF5B6B82),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
