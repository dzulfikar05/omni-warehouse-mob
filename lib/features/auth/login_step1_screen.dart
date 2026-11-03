import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import 'auth_repository.dart';

class LoginStep1Screen extends ConsumerStatefulWidget {
  const LoginStep1Screen({super.key});

  @override
  ConsumerState<LoginStep1Screen> createState() => _LoginStep1ScreenState();
}

class _LoginStep1ScreenState extends ConsumerState<LoginStep1Screen> {
  // Input diawali kosong agar operator memasukkan ID Tenant yang relevan
  final _tenantController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _tenantController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyTenant() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final slug = _tenantController.text.trim().toLowerCase();
      final tenant = await ref.read(authRepositoryProvider).verifyTenant(slug);

      if (!mounted) return;

      ref
          .read(authProvider.notifier)
          .setTenant(tenantSlug: tenant.slug, tenantName: tenant.name);
      context.go('/login/credentials', extra: tenant);
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                  letterSpacing: -0.6,
                                  color: AppColors.textPrimary,
                                  fontFamily: 'PlusJakartaSans',
                                ),
                              ),
                              const SizedBox(height: 34),
                              _inputLabel(),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _tenantController,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF565E74),
                                  fontFamily: 'Inter',
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFFF4F4F4),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  hintText: 'Masukkan Tenant ID',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Workspace Tenant ID wajib diisi';
                                  }
                                  return null;
                                },
                              ),
                              const Spacer(),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _handleVerifyTenant,
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
                                          'Verify Tenant',
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

  Widget _inputLabel() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(Icons.domain_outlined, size: 16, color: AppColors.textPrimary),
          SizedBox(width: 6),
          Text(
            'Workspace Tenant ID',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
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

class BlurCircle extends StatelessWidget {
  const BlurCircle({super.key, required this.color, this.size = 220});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
