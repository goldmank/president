import 'package:flutter/material.dart';

import 'president_theme.dart';

enum AuthMode { signIn, signUp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.signIn;

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == AuthMode.signUp;

    return Scaffold(
      backgroundColor: presidentBackground,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.75, -0.8),
                  radius: 0.9,
                  colors: <Color>[
                    presidentPrimary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _AuthGridPainter())),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 18, 0),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: presidentPrimary,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          children: <Widget>[
                            const Text(
                              'THE TABLE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: presidentPrimary,
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.8,
                                height: 0.95,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'EXECUTIVE STRATEGY SIMULATION',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: presidentMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4.0,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                22,
                                22,
                                18,
                              ),
                              decoration: BoxDecoration(
                                color: presidentSurfaceContainer.withValues(
                                  alpha: 0.88,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.04),
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.36),
                                    blurRadius: 36,
                                    offset: const Offset(0, 20),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  _AuthModeToggle(
                                    mode: _mode,
                                    onChanged: (AuthMode mode) {
                                      setState(() {
                                        _mode = mode;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 22),
                                  if (isSignUp) ...<Widget>[
                                    const _FieldLabel('Name'),
                                    const SizedBox(height: 8),
                                    const _AuthInput(hint: 'YOUR NAME'),
                                    const SizedBox(height: 18),
                                  ],
                                  const _FieldLabel('Username'),
                                  const SizedBox(height: 8),
                                  const _AuthInput(hint: 'CORPORATE IDENTITY'),
                                  const SizedBox(height: 18),
                                  const _FieldLabel('Password'),
                                  const SizedBox(height: 8),
                                  const _AuthInput(
                                    hint: '••••••••',
                                    obscureText: true,
                                  ),
                                  if (isSignUp) ...<Widget>[
                                    const SizedBox(height: 18),
                                    const _FieldLabel('Confirm Password'),
                                    const SizedBox(height: 8),
                                    const _AuthInput(
                                      hint: '••••••••',
                                      obscureText: true,
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: () =>
                                          _showPlaceholder(context),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: presidentPrimary,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        isSignUp
                                            ? 'CREATE ACCOUNT'
                                            : 'ENTER THE BOARDROOM',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  const _DividerLabel(
                                    label: 'AUTHORIZED ACCESS',
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _showGooglePlaceholder(context),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: presidentText,
                                        side: BorderSide.none,
                                        backgroundColor: presidentSurfaceHigh,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                          horizontal: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                      ),
                                      icon: const _GoogleMark(),
                                      label: Text(
                                        isSignUp
                                            ? 'CONTINUE WITH GOOGLE'
                                            : 'SIGN IN WITH GOOGLE',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Center(
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 6,
                                      children: <Widget>[
                                        Text(
                                          isSignUp
                                              ? 'Already have an account?'
                                              : 'New candidate?',
                                          style: const TextStyle(
                                            color: presidentMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _mode = isSignUp
                                                  ? AuthMode.signIn
                                                  : AuthMode.signUp;
                                            });
                                          },
                                          child: Text(
                                            isSignUp
                                                ? 'SIGN IN'
                                                : 'CREATE ACCOUNT',
                                            style: const TextStyle(
                                              color: presidentPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPlaceholder(BuildContext context) {
    final text = _mode == AuthMode.signUp
        ? 'Account creation is not wired yet.'
        : 'Sign in is not wired yet.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _showGooglePlaceholder(BuildContext context) {
    final text = _mode == AuthMode.signUp
        ? 'Google sign up is not wired yet.'
        : 'Google sign in is not wired yet.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.mode, required this.onChanged});

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: presidentSurfaceLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ModeButton(
              label: 'SIGN IN',
              selected: mode == AuthMode.signIn,
              onTap: () => onChanged(AuthMode.signIn),
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'CREATE ACCOUNT',
              selected: mode == AuthMode.signUp,
              onTap: () => onChanged(AuthMode.signUp),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? presidentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.black : presidentMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: presidentMuted,
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _AuthInput extends StatelessWidget {
  const _AuthInput({required this.hint, this.obscureText = false});

  final String hint;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscureText,
      style: const TextStyle(
        color: presidentText,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: presidentOutline.withValues(alpha: 0.6),
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: presidentOutlineVariant),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: presidentPrimary),
        ),
      ),
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Divider(
            color: presidentOutlineVariant.withValues(alpha: 0.35),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: presidentOutline,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: presidentOutlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        color: presidentText,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AuthGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;
    const spacing = 24.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x + 2, y + 2), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
