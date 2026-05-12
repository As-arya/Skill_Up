import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'main_shell.dart';
import 'loading_overlay.dart';
import 'api_service.dart';
import 'user_session.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();


  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = await ApiService.instance.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        university: '',
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (data['user'] != null) {
        UserSession.instance.set(
          id: data['user']['id'],
          name: data['user']['name'],
          email: data['user']['email'],
          token: data['token'] ?? '',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainShell()),
        );
      } else {
        final errorMsg = data['error'] ?? 'Registration failed. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Cannot reach server.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _buildTextField({
    required String label,
    required String hintText,
    required IconData prefixIcon,
    required TextEditingController controller,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onVisibilityToggle,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword && !isVisible,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white30),
            prefixIcon: Icon(prefixIcon, color: Colors.white54, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white54,
                      size: 20,
                    ),
                    onPressed: onVisibilityToggle,
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFF151C2C),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF222B40)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF13B5EA)),
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 8),
          Text(
            helperText,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF13B5EA), Color(0xFF2C6CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF13B5EA,
                            ).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.bolt,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF13B5EA), Color(0xFF2C6CFF)],
                      ).createShader(bounds),
                      child: const Text(
                        'SkillUp',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Create your account',
                      style: TextStyle(color: Colors.white60, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildTextField(
                    label: 'Full Name',
                    hintText: 'full name',
                    prefixIcon: Icons.person_outline,
                    controller: _nameController,
                  ),
                  _buildTextField(
                    label: 'Email',
                    hintText: 'email@gmail.com',
                    prefixIcon: Icons.mail_outline,
                    controller: _emailController,
                  ),
                  _buildTextField(
                    label: 'Password',
                    hintText: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    controller: _passwordController,
                    isPassword: true,
                    isVisible: _isPasswordVisible,
                    onVisibilityToggle: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                    helperText:
                        'At least 8 characters with uppercase, lowercase, and numbers',
                  ),
                  _buildTextField(
                    label: 'Confirm Password',
                    hintText: '••••••••',
                    prefixIcon: Icons.lock_outline,
                    controller: _confirmController,
                    isPassword: true,
                    isVisible: _isConfirmPasswordVisible,
                    onVisibilityToggle: () => setState(
                      () => _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible,
                    ),
                  ),

                  const SizedBox(height: 16),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF13B5EA), Color(0xFF2C6CFF)],
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign in',
                            style: const TextStyle(
                              color: Color(0xFF13B5EA),
                              fontWeight: FontWeight.w600,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const LoadingOverlay(),
        ],
      ),
    );
  }
}
