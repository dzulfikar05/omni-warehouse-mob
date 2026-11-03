import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import 'auth_model.dart';
import 'auth_repository.dart';
import 'login_step1_screen.dart';

class LoginStep2Screen extends ConsumerStatefulWidget {
  const LoginStep2Screen({super.key, this.tenantInfo});

  final TenantInfo? tenantInfo;

  @override
  ConsumerState<LoginStep2Screen> createState() => _LoginStep2ScreenState();
}

class _LoginStep2ScreenState extends ConsumerState<LoginStep2Screen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tenantSlug =
          widget.tenantInfo?.slug ?? ref.read(authProvider).tenantSlug;
      if (tenantSlug == null || tenantSlug.isEmpty) {
        context.go('/login/tenant');
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authState = ref.read(authProvider);
    final tenantSlug = widget.tenantInfo?.slug ?? authState.tenantSlug;
    if (tenantSlug == null || tenantSlug.isEmpty) {
      _showSnackBar('Tenant tidak valid. Silakan verifikasi ulang.');
      context.go('/login/tenant');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(
            workspaceSlug: tenantSlug,
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      if (!mounted) return;

      await ref
          .read(authProvider.notifier)
          .saveSession(
            token: session.token,
            tenantSlug: session.tenantSlug,
            tenantName: session.tenantName,
            userName: session.userName,
            userRole: session.userRole,
          );

      if (!mounted) return;
      context.go('/dashboard');
    } on ValidationException catch (e) {
      if (!mounted) return;
      final errorMsg = e.getFirstError('email') ?? e.message;
      _showSnackBar(errorMsg);
    } on AppException catch (e) {
      if (!mounted) return;
      _showSnackBar(e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final tenantName = widget.tenantInfo?.name ?? authState.tenantName ?? '';
    final tenantSlug = widget.tenantInfo?.slug ?? authState.tenantSlug ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          const Positioned(
            left: -107,
            top: -16,
            child: BlurCircle(color: Color(0x4DDBE1FF)),
          ),
          const Positioned(
            right: -105,
            bottom: 38,
            child: BlurCircle(color: Color(0x66D9E2FD)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 34),
                      child: IntrinsicHeight(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 24),
                              _brandChip(),
                              const SizedBox(height: 32),
                              _logoContainer(),
                              const SizedBox(height: 32),
                              const Text(
                                'Login Operator Gudang',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'PlusJakartaSans',
                                ),
                              ),
                              const SizedBox(height: 32),

                              // TENANT BADGE HEADER (DINAMIS)
                              _tenantHeader(tenantName),
                              const SizedBox(height: 10),
                              _readonlyContainer(tenantSlug),
                              const SizedBox(height: 18),

                              // EMAIL FIELD (DINAMIS HINT)
                              _fieldLabel(Icons.email_outlined, 'Email'),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF565E74),
                                  fontFamily: 'Inter',
                                ),
                                decoration: _inputDecoration(
                                  tenantSlug.isNotEmpty
                                      ? 'operator@$tenantSlug.com'
                                      : 'nama@email.com',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Email wajib diisi';
                                  }
                                  if (!v.contains('@')) {
                                    return 'Format email tidak valid';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),

                              // PASSWORD FIELD
                              _fieldLabel(Icons.lock_outline, 'Password'),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF565E74),
                                  fontFamily: 'Inter',
                                ),
                                decoration: _inputDecoration('••••••••')
                                    .copyWith(
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          size: 18,
                                          color: const Color(0xFF9CA3AF),
                                        ),
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                                      ),
                                    ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Password wajib diisi'
                                    : null,
                              ),

                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: _isLoading
                                      ? const SizedBox.shrink()
                                      : const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                  label: _isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Masuk ke Dashboard',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 42),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      hintText: hint,
    );
  }

  Widget _tenantHeader(String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _fieldLabel(Icons.domain_outlined, 'Workspace Tenant ID'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x1A007D5B),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 12,
                color: Color(0xFF006243),
              ),
              const SizedBox(width: 4),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF006243),
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _readonlyContainer(String text) {
    return Container(
      width: double.infinity,
      height: 45,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF565E74),
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _fieldLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textPrimary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Widget _logoContainer() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        'assets/icons/logo_wms.svg',
        width: 64,
        height: 64,
      ),
    );
  }

  Widget _brandChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE5EEFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icons/logo_wms.svg', width: 14, height: 14),
          const SizedBox(width: 6),
          const Text(
            'OmniWarehouse Ecosystem',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF004AC6),
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
