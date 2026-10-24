import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_app_bar.dart';
import '../../shared/widgets/omni_snackbar.dart';
import '../../shared/widgets/omni_status_badge.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  String _selectedShift = 'pagi';

  final List<Map<String, String>> _shiftOptions = [
    {'value': 'pagi', 'label': 'Shift Pagi (08:00 - 16:00 WIB)'},
    {'value': 'siang', 'label': 'Shift Siang (13:00 - 21:00 WIB)'},
    {'value': 'malam', 'label': 'Shift Malam (21:00 - 05:00 WIB)'},
  ];

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authProvider);
    _nameController = TextEditingController(text: auth.userName ?? 'Budi Santoso');
    _phoneController = TextEditingController(text: '+62 812-3456-7890');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    const userEmail = 'budi.santoso@omniwarehouse.co';
    final tenantName = auth.tenantName ?? 'Gudang Malang (Hub Jawa Timur)';
    final initials = _getInitials(_nameController.text);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const OmniAppBar(),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // Header Navigation Back Strip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => context.go('/more/profile'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textPrimary),
                          SizedBox(width: 6),
                          Text(
                            'Kembali ke Profil',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Text(
                    'MODE EDIT',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'RobotoMono',
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Edit Avatar Header Card
              _buildAvatarCard(initials),
              const SizedBox(height: 14),

              // Form Section 1: Data Pribadi & Kontak Lapangan
              _buildPersonalDataCard(userEmail),
              const SizedBox(height: 14),

              // Form Section 2: Penugasan & Shift (Terkunci HR)
              _buildAssignmentCard(tenantName),
              const SizedBox(height: 16),

              // Form Submit & Cancel Actions
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCard(String initials) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -6,
                right: -6,
                child: InkWell(
                  onTap: () {
                    OmniSnackbar.show(
                      context,
                      message: 'Akses kamera diaktifkan untuk ganti foto',
                      icon: Icons.photo_camera_rounded,
                    );
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.photo_camera_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: () {
                  OmniSnackbar.show(
                    context,
                    message: 'Pilih foto dari galeri perangkat',
                    icon: Icons.image_rounded,
                  );
                },
                child: const Text(
                  'Unggah Foto Baru',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('•', style: TextStyle(color: AppColors.borderStrong)),
              ),
              InkWell(
                onTap: () {
                  OmniSnackbar.show(
                    context,
                    message: 'Foto profil dihapus, kembali ke inisial',
                    icon: Icons.delete_outline_rounded,
                    iconColor: AppColors.danger,
                  );
                },
                child: const Text(
                  'Hapus Foto',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Format JPG/PNG, ukuran file maksimal 2 MB',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDataCard(String userEmail) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.badge_outlined, color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Text(
                'Data Pribadi & Kontak Lapangan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Field: Nama Lengkap Operator *
          _buildFieldLabel('Nama Lengkap Operator', isRequired: true),
          const SizedBox(height: 6),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            decoration: _inputDecoration(
              hint: 'Nama Lengkap',
              prefixIcon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 12),

          // Field: Email Resmi (Read-Only SSO)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel('Alamat Email Resmi'),
              const OmniStatusBadge(
                label: 'TERVERIFIKASI',
                variant: OmniBadgeVariant.success,
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            readOnly: true,
            controller: TextEditingController(text: userEmail),
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'RobotoMono',
              color: AppColors.textSecondary,
            ),
            decoration: _inputDecoration(
              hint: 'Email',
              prefixIcon: Icons.mail_outline_rounded,
              suffixIcon: Icons.lock_outline_rounded,
              fillColor: const Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Email perusahaan terhubung dengan Single Sign-On (SSO).',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          // Field: Nomor WhatsApp / Dispatch Darurat *
          _buildFieldLabel('Nomor WhatsApp / Dispatch Darurat', isRequired: true),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'RobotoMono',
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: _inputDecoration(
              hint: 'Nomor WhatsApp',
              prefixIcon: Icons.phone_android_rounded,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Digunakan untuk notifikasi darurat operasional & staging bay hub.',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(String tenantName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings_outlined, color: AppColors.textSecondary, size: 16),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Informasi Penugasan & Shift',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 10, color: AppColors.textSecondary),
                    SizedBox(width: 3),
                    Text(
                      'Terkunci HR',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'RobotoMono',
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // NIK / ID Pegawai
          _buildFieldLabel('ID Pegawai (NIK)'),
          const SizedBox(height: 6),
          TextField(
            readOnly: true,
            controller: TextEditingController(text: 'WH-90241'),
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'RobotoMono',
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
            decoration: _inputDecoration(
              hint: 'ID Pegawai',
              fillColor: const Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 12),

          // Lokasi DC Hub
          _buildFieldLabel('Lokasi DC / Hub Penugasan'),
          const SizedBox(height: 6),
          TextField(
            readOnly: true,
            controller: TextEditingController(text: tenantName),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            decoration: _inputDecoration(
              hint: 'Lokasi DC',
              prefixIcon: Icons.warehouse_outlined,
              suffixIcon: Icons.lock_outline_rounded,
              fillColor: const Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Perubahan cabang DC hanya dapat diajukan melalui portal mutasi HRIS.',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),

          // Shift Dropdown
          _buildFieldLabel('Pilihan Shift Kerja Lapangan'),
          const SizedBox(height: 6),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedShift,
                isExpanded: true,
                icon: const Icon(Icons.unfold_more_rounded, size: 18, color: AppColors.textSecondary),
                items: _shiftOptions.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt['value'],
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          opt['label']!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedShift = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              final name = _nameController.text.trim();
              OmniSnackbar.show(
                context,
                message: 'Profil $name berhasil disimpan!',
                icon: Icons.badge_outlined,
              );
              Future.delayed(const Duration(milliseconds: 600), () {
                if (context.mounted) context.go('/more/profile');
              });
            },
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text(
              'Simpan Perubahan Profil',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: () => context.go('/more/profile'),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 2),
          const Text(
            '*',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    IconData? prefixIcon,
    IconData? suffixIcon,
    Color? fillColor,
  }) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: fillColor ?? AppColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: AppColors.textMuted) : null,
      suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 18, color: AppColors.textMuted) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'BS';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
