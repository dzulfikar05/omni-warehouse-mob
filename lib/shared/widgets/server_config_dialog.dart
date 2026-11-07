import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';

/// Modal dialog modern untuk mengubah alamat server Laravel backend langsung dari HP.
class ServerConfigDialog extends ConsumerStatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ServerConfigDialog(),
    );
  }

  @override
  ConsumerState<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends ConsumerState<ServerConfigDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: AppConfig.baseUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyPreset(String presetUrl) {
    setState(() {
      _controller.text = presetUrl;
    });
  }

  Future<void> _handleSave() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    await updateAppBaseUrl(ref, input);
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Server dialihkan ke: ${AppConfig.baseUrl}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleReset() async {
    await resetAppBaseUrl(ref);
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Server di-reset ke bawaan: ${AppConfig.baseUrl}'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = AppConfig.isCustom;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF), // blue-50
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              LucideIcons.server,
              color: Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const Gap(10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengaturan Server',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                Gap(2),
                Text(
                  'Ubah host backend Laravel saat pengujian',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF64748B),
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(12),

            // Status chip saat ini
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCustom
                    ? const Color(0xFFFEF3C7) // amber-100
                    : const Color(0xFFECFDF5), // emerald-50
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCustom
                      ? const Color(0xFFFDE68A)
                      : const Color(0xFFA7F3D0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCustom ? LucideIcons.wrench : LucideIcons.circleCheck,
                    size: 14,
                    color: isCustom
                        ? const Color(0xFFD97706)
                        : const Color(0xFF059669),
                  ),
                  const Gap(6),
                  Expanded(
                    child: Text(
                      isCustom ? 'Mode Override Aktif' : 'Mode Default Sistem',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isCustom
                            ? const Color(0xFFB45309)
                            : const Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(14),

            // Label
            const Text(
              'Alamat URL Backend (Host & Port):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF334155),
              ),
            ),
            const Gap(6),

            // Input field
            TextField(
              controller: _controller,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'RobotoMono',
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'http://10.0.2.2:8000/api',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                ),
              ),
            ),
            const Gap(14),

            // Presets
            const Text(
              'Pilihan Cepat (Presets):',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const Gap(8),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildPresetChip(
                  label: 'Emulator (10.0.2.2)',
                  url: 'http://10.0.2.2:8000/api',
                  icon: LucideIcons.smartphone,
                ),
                _buildPresetChip(
                  label: 'Localhost (127.0.0.1)',
                  url: 'http://127.0.0.1:8000/api',
                  icon: LucideIcons.laptop,
                ),
                _buildPresetChip(
                  label: 'Wi-Fi Laptop (172.20.10.3)',
                  url: 'http://172.20.10.3:8000/api',
                  icon: LucideIcons.network,
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (isCustom)
          TextButton.icon(
            onPressed: _handleReset,
            icon: const Icon(LucideIcons.rotateCcw, size: 14),
            label: const Text('Reset'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _buildPresetChip({
    required String label,
    required String url,
    required IconData icon,
  }) {
    final isSelected = _controller.text.trim() == url;
    return InkWell(
      onTap: () => _applyPreset(url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEFF6FF)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF475569),
            ),
            const Gap(5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
