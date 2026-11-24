import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import 'omni_feature_menu.dart';

Future<void> _showQuickAccess(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  backgroundColor: Colors.white,
  constraints: const BoxConstraints(maxWidth: 480),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
  ),
  builder: (sheetContext) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Akses Cepat',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _QuickAccessTile(
          icon: Icons.inbox_rounded,
          title: 'Daftar Inbound',
          subtitle: 'Buka daftar penerimaan barang',
          onTap: () {
            Navigator.pop(sheetContext);
            context.go('/inbound');
          },
        ),
        _QuickAccessTile(
          icon: Icons.outbox_rounded,
          title: 'Daftar Outbound',
          subtitle: 'Buka daftar pengiriman barang',
          onTap: () {
            Navigator.pop(sheetContext);
            context.go('/outbound');
          },
        ),
        _QuickAccessTile(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Buka Scanner',
          subtitle: 'Pindai dokumen, rak, atau SKU',
          onTap: () {
            Navigator.pop(sheetContext);
            context.go('/scanner');
          },
        ),
      ],
    ),
  ),
);

class OmniBottomNav extends StatelessWidget {
  const OmniBottomNav({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = shell.currentIndex;

    return Scaffold(
      body: shell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        width: 58,
        height: 58,
        margin: const EdgeInsets.only(top: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF3B82F6)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white, width: 3.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showQuickAccess(context),
            borderRadius: BorderRadius.circular(18),
            child: const Tooltip(
              message: 'Akses cepat',
              child: Center(
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _BottomNavItem(
                  label: 'Dashboard',
                  icon: Icons.grid_view_rounded,
                  selected: selectedIndex == 0,
                  onTap: () => _goBranch(0),
                ),
                _BottomNavItem(
                  label: 'Inbound',
                  icon: Icons.inbox_rounded,
                  selected: selectedIndex == 1,
                  onTap: () => _goBranch(1),
                ),
                const SizedBox(width: 68),
                _BottomNavItem(
                  label: 'Outbound',
                  icon: Icons.outbox_rounded,
                  selected: selectedIndex == 3,
                  onTap: () => _goBranch(3),
                ),
                _BottomNavItem(
                  label: 'Lainnya',
                  icon: Icons.widgets_rounded,
                  selected: selectedIndex == 4,
                  hasBadge: true,
                  onTap: () => showOmniFeatureMenu(
                    context,
                    onSelect: (location) => context.go(location),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBranch(int index) {
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: Icon(icon, color: AppColors.primary),
    title: Text(
      title,
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.hasBadge = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 22, color: color),
                  if (hasBadge)
                    Positioned(
                      top: -1,
                      right: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
