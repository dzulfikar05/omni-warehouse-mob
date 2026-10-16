import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_model.dart';

class NotificationState {
  final List<AppNotification> items;
  final bool notifyNewTasks;
  final bool notifyStockAlerts;
  final bool soundEnabled;

  const NotificationState({
    required this.items,
    this.notifyNewTasks = true,
    this.notifyStockAlerts = true,
    this.soundEnabled = true,
  });

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationState copyWith({
    List<AppNotification>? items,
    bool? notifyNewTasks,
    bool? notifyStockAlerts,
    bool? soundEnabled,
  }) {
    return NotificationState(
      items: items ?? this.items,
      notifyNewTasks: notifyNewTasks ?? this.notifyNewTasks,
      notifyStockAlerts: notifyStockAlerts ?? this.notifyStockAlerts,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier()
      : super(
          NotificationState(
            items: [
              AppNotification(
                id: 'notif-001',
                title: 'Inbound PO-2026-1040 Tiba',
                body: 'Kontainer CV. Megah Elektrik telah bersandar di Dock Bay 04. Validasi 120 unit MCB & Panel sekarang.',
                dateText: '10 mnt lalu',
                timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
                isRead: false,
                type: NotificationType.inbound,
                avatarText: 'IN',
                avatarBg: const Color(0xFFEFF6FF), // blue-50
                avatarTextColor: const Color(0xFF2563EB), // primary blue
                routeAction: '/inbound/PO-2026-1040',
                actionLabel: 'Buka Scanner Validasi PO',
                metadata: {
                  'Nomor PO': 'PO-2026-1040',
                  'Supplier': 'CV. Megah Elektrik',
                  'Lokasi': 'Dock Bay 04',
                  'Target Unit': '120 Units (Panel & MCB)',
                },
              ),
              AppNotification(
                id: 'notif-002',
                title: 'Prioritas Picking SO-2025-1102',
                body: 'Order ekspres Toko Berkah Retail Jaya butuh pengemasan segera sebelum cut-off jam 16:00.',
                dateText: '1 jam lalu',
                timestamp: DateTime.now().subtract(const Duration(hours: 1)),
                isRead: false,
                type: NotificationType.outbound,
                avatarText: 'OUT',
                avatarBg: const Color(0xFFECFDF5), // emerald-50
                avatarTextColor: const Color(0xFF059669), // emerald-600
                routeAction: '/outbound/SO-2025-1102',
                actionLabel: 'Mulai Picking Barang',
                metadata: {
                  'Nomor SO': 'SO-2025-1102',
                  'Pelanggan': 'Toko Berkah Retail Jaya',
                  'Ekspedisi': 'J&T Cargo Express',
                  'Status': 'Picking (15/50 SKU)',
                },
              ),
              AppNotification(
                id: 'notif-003',
                title: 'Audit Opname OP-2026-001',
                body: 'Sesi audit siklus lorong A & B sedang berjalan. 15 SKU telah dicatat fisik oleh tim shift pagi.',
                dateText: 'Kemarin',
                timestamp: DateTime.now().subtract(const Duration(days: 1)),
                isRead: true,
                type: NotificationType.opname,
                avatarText: 'OP',
                avatarBg: const Color(0xFFFFFBEB), // amber-50
                avatarTextColor: const Color(0xFFD97706), // amber-600
                routeAction: '/more/opname/OP-2026-001',
                actionLabel: 'Lanjut Hitung Fisik Rak',
                metadata: {
                  'Kode Sesi': 'OP-2026-001',
                  'Area Audit': 'Rak A1 - A4 & B1',
                  'Progres': '15 / 24 SKU Terhitung',
                  'Status': 'IN PROGRESS',
                },
              ),
              AppNotification(
                id: 'notif-004',
                title: 'Sinkronisasi Berhasil',
                body: '3 transaksi antrean offline lokal telah berhasil diperbarui ke server pusat.',
                dateText: '14 Okt, 2026',
                timestamp: DateTime.now().subtract(const Duration(days: 2)),
                isRead: true,
                type: NotificationType.system,
                avatarText: 'WMS',
                avatarBg: const Color(0xFFF1F5F9), // slate-100
                avatarTextColor: const Color(0xFF475569), // slate-600
                routeAction: '/more/sync',
                actionLabel: 'Lihat Riwayat Sync',
                metadata: {
                  'Antrean': '3 Berkas Diproses',
                  'Status': 'Sinkron 100%',
                  'Server': 'Naratel Cloud Hub',
                },
              ),
            ],
          ),
        );

  void markAsRead(String id) {
    state = state.copyWith(
      items: state.items.map((it) {
        if (it.id == id) {
          return it.copyWith(isRead: true);
        }
        return it;
      }).toList(),
    );
  }

  void markAllAsRead() {
    state = state.copyWith(
      items: state.items.map((it) => it.copyWith(isRead: true)).toList(),
    );
  }

  void toggleNotifyNewTasks(bool val) {
    state = state.copyWith(notifyNewTasks: val);
  }

  void toggleNotifyStockAlerts(bool val) {
    state = state.copyWith(notifyStockAlerts: val);
  }

  void toggleSound(bool val) {
    state = state.copyWith(soundEnabled: val);
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  return NotificationNotifier();
});
