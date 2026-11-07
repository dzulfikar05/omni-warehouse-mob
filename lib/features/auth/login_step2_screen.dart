import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/server_config_dialog.dart';
import 'auth_model.dart';
import 'auth_repository.dart';

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
  bool _rememberDevice = true;

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
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final tenantName = widget.tenantInfo?.name ?? authState.tenantName ?? 'PT Demo Logistik';
    final tenantSlug = widget.tenantInfo?.slug ?? authState.tenantSlug ?? 'demo-tenant';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- 1. TOP HEADER APP BAR (Logiflow ID / Back / Help) ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(
                                LucideIcons.arrowLeft,
                                size: 22,
                                color: Color(0xFF334155),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => context.go('/login/tenant'),
                              tooltip: 'Kembali',
                            ),
                            const Text(
                              'OMNIWAREHOUSE ID',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                                color: Color(0xFF94A3B8),
                                fontFamily: 'Inter',
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                LucideIcons.circleHelp,
                                size: 20,
                                color: Color(0xFF94A3B8),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Hubungi Supervisor Gudang jika ada kendala akun.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              tooltip: 'Bantuan',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // --- 2. LOGO SQUIRCLE ICON ---
                        Center(
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF), // soft blue-50
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: SvgPicture.asset(
                              'assets/icons/logo_wms.svg',
                              width: 38,
                              height: 38,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // --- 3. TITLE & SUBTITLE ---
                        const Text(
                          'Login Operator Gudang',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A), // Slate-900
                            letterSpacing: -0.4,
                            fontFamily: 'PlusJakartaSans',
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Masukkan kredensial operator untuk\nsinkronisasi inventaris',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B), // Slate-500
                            height: 1.35,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- 4. TENANT INFO CARD (Presisi & Seimbang sesuai referensi) ---
                        _buildTenantCard(tenantName, tenantSlug),
                        const SizedBox(height: 20),

                        // --- 5. EMAIL FIELD (Tanpa Icon Redundan pada Label) ---
                        const Text(
                          'Email Operator',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155), // Slate-700
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                            fontFamily: 'Inter',
                          ),
                          decoration: _buildInputDecoration(
                            hint: tenantSlug.isNotEmpty
                                ? 'operator@$tenantSlug.com'
                                : 'nama@demo-tenant.com',
                            prefixIcon: LucideIcons.mail,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email operator wajib diisi';
                            }
                            if (!v.contains('@')) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // --- 6. PASSWORD FIELD WITH FORGOT PASSWORD LINK ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Kata Sandi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                                fontFamily: 'Inter',
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Silakan hubungi Administrator untuk reset sandi.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              child: const Text(
                                'Lupa Sandi?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB), // Blue-600
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                            fontFamily: 'Inter',
                          ),
                          decoration: _buildInputDecoration(
                            hint: '••••••••',
                            prefixIcon: LucideIcons.lock,
                          ).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? LucideIcons.eyeOff
                                    : LucideIcons.eye,
                                size: 19,
                                color: const Color(0xFF94A3B8),
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Kata sandi wajib diisi'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // --- 7. CHECKBOX & VERSION ROW ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _rememberDevice,
                                    onChanged: (v) =>
                                        setState(() => _rememberDevice = v ?? true),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    activeColor: const Color(0xFF2563EB),
                                    side: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Ingat perangkat scanner ini',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF475569),
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'v2.4.1',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                                fontFamily: 'RobotoMono',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // --- 8. ACTION SUBMIT BUTTON ---
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB), // Tailwind Blue-600
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF93C5FD),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.2,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Masuk ke Dashboard',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        LucideIcons.arrowRight,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // --- 9. FOOTER KENDALA LOGIN (Teks Biru) ---
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Kendala login? ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF64748B),
                                  fontFamily: 'Inter',
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                    ),
                                    builder: (ctx) => Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Pusat Bantuan Operator',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Jika Anda lupa sandi atau workspace ID tidak ditemukan, hubungi Supervisor Gudang atau tim IT WMS di shift Anda.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF64748B),
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 40,
                                            child: OutlinedButton.icon(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                ServerConfigDialog.show(context);
                                              },
                                              icon: const Icon(LucideIcons.server, size: 15),
                                              label: const Text('Pengaturan Alamat Server'),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF2563EB),
                                                side: const BorderSide(color: Color(0xFFBFDBFE)),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 44,
                                            child: ElevatedButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2563EB),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                              ),
                                              child: const Text('Mengerti'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Hubungi Supervisor Gudang',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB), // Warna biru
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- WIDGET HELPER: TENANT CARD (Sesuai Referensi React & Gambar) ---

  Widget _buildTenantCard(String name, String slug) {
    final displayName = name.isNotEmpty ? name : 'PT Demo Logistik';
    final displaySlug = slug.isNotEmpty ? slug : 'demo-tenant';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // slate-50/80
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)), // slate-200
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left building icon box
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              LucideIcons.building2,
              size: 19,
              color: Color(0xFF475569), // slate-600
            ),
          ),
          const SizedBox(width: 10),

          // Middle Tenant Name & Workspace ID (Bebas terpotong, breathing room lega)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A), // slate-900
                    fontFamily: 'Inter',
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'workspace: ' + displaySlug,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B), // slate-500
                    fontFamily: 'RobotoMono',
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right Verified Badge (Emerald pill - presisi & proporsional)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5), // emerald-50
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFA7F3D0)), // emerald-200
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.circleCheck,
                  size: 12,
                  color: Color(0xFF059669), // emerald-600
                ),
                SizedBox(width: 3.5),
                Text(
                  'Terverifikasi',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF047857), // emerald-700
                    fontFamily: 'Inter',
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- INPUT DECORATION HELPER ---
  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        color: Color(0xFF94A3B8), // slate-400
        fontFamily: 'Inter',
      ),
      prefixIcon: Icon(
        prefixIcon,
        size: 18,
        color: const Color(0xFF94A3B8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE11D48)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
      ),
    );
  }
}
