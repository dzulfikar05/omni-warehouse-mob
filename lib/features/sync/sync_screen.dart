import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/omni_app_bar.dart';
import '../../shared/widgets/omni_snackbar.dart';

class SyncItemModel {
  SyncItemModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.statusBg,
    required this.time,
    required this.size,
    required this.uuid,
    required this.icon,
    required this.payloadJson,
  });

  final String id;
  final String title;
  final String subtitle;
  final String statusLabel;
  final Color statusColor;
  final Color statusBg;
  final String time;
  final String size;
  final String uuid;
  final IconData icon;
  final Map<String, dynamic> payloadJson;
}

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _isSyncingAll = false;
  String? _syncingItemId;

  late List<SyncItemModel> _queueItems;

  @override
  void initState() {
    super.initState();
    _queueItems = [
      SyncItemModel(
        id: '1',
        title: 'Penerimaan PO-2026-1042',
        subtitle: 'Inbound Logistik • 450 Unit',
        statusLabel: 'Siap Kirim',
        statusColor: const Color(0xFF131B2E),
        statusBg: const Color(0xFFDAE2FD),
        time: '10:35 WIB',
        size: '14.2 KB',
        uuid: 'UUID: 8f2a-e1',
        icon: Icons.move_to_inbox_rounded,
        payloadJson: {
          'transaction_type': 'IN',
          'manifest_code': 'PO-2026-1042',
          'supplier': 'PT Distribusi Utama Elektronik',
          'dock_bay': 'Dock Bay 04',
          'total_units': 450,
          'good_units': 448,
          'damaged_units': 2,
          'target_rack': 'RACK-A1-01',
          'operator': 'Budi Santoso',
          'created_at': '2026-10-16T10:35:12Z',
        },
      ),
      SyncItemModel(
        id: '2',
        title: 'Wave Pick #W-104 (DO-8819)',
        subtitle: 'Outbound Dispatch • 6 SKU',
        statusLabel: 'Verifikasi Server',
        statusColor: const Color(0xFF434655),
        statusBg: const Color(0xFFD3E4FE),
        time: '10:41 WIB',
        size: '8.7 KB',
        uuid: 'UUID: 3c9b-f4',
        icon: Icons.outbox_rounded,
        payloadJson: {
          'transaction_type': 'OUT',
          'order_code': 'DO-8819',
          'wave_id': 'W-104',
          'customer': 'Toko Maju Bersama',
          'staging_bay': 'Staging S-01',
          'picked_sku_count': 6,
          'total_items': 120,
          'created_at': '2026-10-16T10:41:40Z',
        },
      ),
      SyncItemModel(
        id: '3',
        title: 'Blind Count Rak B-04',
        subtitle: 'Stock Opname • 15 SKU Fisik',
        statusLabel: 'Siap Sinkron',
        statusColor: const Color(0xFF131B2E),
        statusBg: const Color(0xFFDAE2FD),
        time: '10:44 WIB',
        size: '19.1 KB',
        uuid: 'UUID: d901-aa',
        icon: Icons.fact_check_outlined,
        payloadJson: {
          'transaction_type': 'OPNAME',
          'session_code': 'OPN-2026-B04',
          'rack': 'RACK-B1-04',
          'scanned_skus': 15,
          'matched': 14,
          'variance': 1,
          'variance_type': 'DEFICIT',
          'created_at': '2026-10-16T10:44:22Z',
        },
      ),
    ];
  }

  void _syncAll() async {
    if (_queueItems.isEmpty) {
      OmniSnackbar.show(
        context,
        message: 'Tidak ada antrean berkas offline pending.',
        icon: Icons.done_all_rounded,
      );
      return;
    }

    setState(() => _isSyncingAll = true);
    await Future.delayed(const Duration(milliseconds: 1100));

    if (mounted) {
      final count = _queueItems.length;
      setState(() {
        _isSyncingAll = false;
        _queueItems.clear();
      });

      OmniSnackbar.show(
        context,
        message: '$count Berkas transaksi berhasil disinkronkan ke Laravel!',
        icon: Icons.cloud_done_rounded,
      );
    }
  }

  void _syncSingleItem(SyncItemModel item) async {
    setState(() => _syncingItemId = item.id);
    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      setState(() {
        _syncingItemId = null;
        _queueItems.removeWhere((q) => q.id == item.id);
      });

      OmniSnackbar.show(
        context,
        message: '${item.title} berhasil disinkronkan!',
        icon: Icons.check_circle_rounded,
      );
    }
  }

  void _removeItem(SyncItemModel item) {
    setState(() {
      _queueItems.removeWhere((q) => q.id == item.id);
    });

    OmniSnackbar.show(
      context,
      message: 'Antrean ${item.title} dihapus dari Isar lokal',
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.danger,
    );
  }

  void _showPayloadModal(SyncItemModel item) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(item.payloadJson);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 480),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payload JSON Transaksi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      item.uuid,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'RobotoMono',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 280),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  prettyJson,
                  style: const TextStyle(
                    color: Color(0xFF1E40AF),
                    fontFamily: 'RobotoMono',
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: prettyJson));
                  Navigator.of(ctx).pop();
                  OmniSnackbar.show(
                    context,
                    message: 'JSON berhasil disalin ke clipboard!',
                    icon: Icons.copy_rounded,
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text(
                  'Salin JSON',
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // slate-100
      appBar: const OmniAppBar(),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // Header Back Strip
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => context.go('/dashboard'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.textPrimary),
                          SizedBox(width: 6),
                          Text(
                            'Kembali ke Dashboard',
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primaryBorder),
                    ),
                    child: const Text(
                      'ISAR OFFLINE MANAGER',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'RobotoMono',
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Hero Blue Sync Overview Card
              _buildHeroSyncCard(),
              const SizedBox(height: 16),

              // Section Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DAFTAR ANTREAN TRANSAKSI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'RobotoMono',
                      color: AppColors.textMuted,
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    '${_queueItems.length} Menunggu',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'RobotoMono',
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Queue List
              if (_queueItems.isEmpty)
                _buildEmptyState()
              else
                ..._queueItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildQueueCard(item),
                    )),

              const SizedBox(height: 14),

              // Bottom Action Button: Ekspor Log
              InkWell(
                onTap: () {
                  OmniSnackbar.show(
                    context,
                    message: 'Log sinkronisasi diekspor: sync_log_20261016.json',
                    icon: Icons.file_download_done_rounded,
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5EEFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF0B1C30)),
                      SizedBox(width: 8),
                      Text(
                        'Ekspor Log Sinkronisasi (.json)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0B1C30),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSyncCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Watermark Icon
          Positioned(
            right: -12,
            bottom: -16,
            child: Icon(
              Icons.sync_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Auto-Sync pill & retry interval
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.autorenew_rounded, size: 13, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Sinkronisasi Otomatis Aktif',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Auto-Retry (60s)',
                      style: TextStyle(
                        color: Color(0xFFEEEFFF),
                        fontSize: 11,
                        fontFamily: 'RobotoMono',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Main Metric: Count
                Text(
                  '${_queueItems.length} Berkas',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _queueItems.isEmpty
                      ? 'Semua data telah disinkronkan ke server pusat'
                      : 'Terakhir sukses: 14 menit yang lalu (10:32 WIB)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 16),

                // Button: Sync Data
                InkWell(
                  onTap: _isSyncingAll ? null : _syncAll,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSyncingAll)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        else
                          const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF004AC6)),
                        const SizedBox(width: 8),
                        Text(
                          _isSyncingAll ? 'Menyinkronkan...' : 'Sync Data',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF004AC6),
                          ),
                        ),
                      ],
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

  Widget _buildQueueCard(SyncItemModel item) {
    final isItemSyncing = _syncingItemId == item.id;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
          // Header Row: Icon + Title/Subtitle + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B1C30),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF434655),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: item.statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.statusLabel,
                  style: TextStyle(
                    color: item.statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Metadata Strip: Time, Size, UUID
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF434655)),
                    const SizedBox(width: 4),
                    Text(
                      item.time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF434655),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.data_usage_rounded, size: 13, color: Color(0xFF434655)),
                    const SizedBox(width: 4),
                    Text(
                      item.size,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF434655),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.fingerprint_rounded, size: 13, color: Color(0xFF434655)),
                    const SizedBox(width: 4),
                    Text(
                      item.uuid,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'RobotoMono',
                        color: Color(0xFF434655),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Footer: Lihat Payload JSON (Left) + Hapus & Retry (Right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => _showPayloadModal(item),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Icon(Icons.code_rounded, size: 15, color: Color(0xFF565E74)),
                      SizedBox(width: 5),
                      Text(
                        'Lihat Payload JSON',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF565E74),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  // Button Hapus
                  InkWell(
                    onTap: () => _removeItem(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 16,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Button Retry Single
                  InkWell(
                    onTap: isItemSyncing ? null : () => _syncSingleItem(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isItemSyncing
                          ? const Center(
                              child: SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.sync_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.cloud_done_rounded, size: 44, color: AppColors.success),
          SizedBox(height: 10),
          Text(
            'Antrean Isar Bersih',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Semua data transaksi lokal telah berhasil dikirim ke server pusat.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
