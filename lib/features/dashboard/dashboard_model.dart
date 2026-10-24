// Model Domain untuk Dashboard WMS
// Selaras dengan skema respon Laravel /api/tenant/{slug}/dashboard/summary

class DashboardKpi {
  final int activeInboundCount;
  final int activeOutboundCount;
  final int pendingTransferCount;
  final int activeOpnameCount;
  final int offlineQueueCount;

  const DashboardKpi({
    this.activeInboundCount = 3,
    this.activeOutboundCount = 2,
    this.pendingTransferCount = 4,
    this.activeOpnameCount = 1,
    this.offlineQueueCount = 0,
  });

  factory DashboardKpi.fromJson(Map<String, dynamic> json) {
    return DashboardKpi(
      activeInboundCount: (json['active_inbound_count'] ?? json['activeInboundCount'] ?? 0) as int,
      activeOutboundCount: (json['active_outbound_count'] ?? json['activeOutboundCount'] ?? 0) as int,
      pendingTransferCount: (json['pending_transfer_count'] ?? json['pendingTransferCount'] ?? 0) as int,
      activeOpnameCount: (json['active_opname_count'] ?? json['activeOpnameCount'] ?? 0) as int,
      offlineQueueCount: (json['offline_queue_count'] ?? json['offlineQueueCount'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'active_inbound_count': activeInboundCount,
    'active_outbound_count': activeOutboundCount,
    'pending_transfer_count': pendingTransferCount,
    'active_opname_count': activeOpnameCount,
    'offline_queue_count': offlineQueueCount,
  };

  DashboardKpi copyWith({
    int? activeInboundCount,
    int? activeOutboundCount,
    int? pendingTransferCount,
    int? activeOpnameCount,
    int? offlineQueueCount,
  }) {
    return DashboardKpi(
      activeInboundCount: activeInboundCount ?? this.activeInboundCount,
      activeOutboundCount: activeOutboundCount ?? this.activeOutboundCount,
      pendingTransferCount: pendingTransferCount ?? this.pendingTransferCount,
      activeOpnameCount: activeOpnameCount ?? this.activeOpnameCount,
      offlineQueueCount: offlineQueueCount ?? this.offlineQueueCount,
    );
  }
}

class DashboardTaskItem {
  final String id;
  final String type; // 'inbound' | 'outbound' | 'transfer' | 'opname'
  final String badgeLabel;
  final String code;
  final String title;
  final String subtitle;
  final int progressCurrent;
  final int progressTotal;
  final String location;
  final String route;

  const DashboardTaskItem({
    required this.id,
    required this.type,
    required this.badgeLabel,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.progressCurrent,
    required this.progressTotal,
    required this.location,
    required this.route,
  });

  double get progressPercent =>
      progressTotal > 0 ? (progressCurrent / progressTotal).clamp(0.0, 1.0) : 0.0;

  factory DashboardTaskItem.fromJson(Map<String, dynamic> json) {
    return DashboardTaskItem(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'inbound',
      badgeLabel: json['badge_label']?.toString() ?? 'TASK',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      progressCurrent: (json['progress_current'] ?? json['progressCurrent'] ?? 0) as int,
      progressTotal: (json['progress_total'] ?? json['progressTotal'] ?? 1) as int,
      location: json['location']?.toString() ?? '',
      route: json['route']?.toString() ?? '/dashboard',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'badge_label': badgeLabel,
    'code': code,
    'title': title,
    'subtitle': subtitle,
    'progress_current': progressCurrent,
    'progress_total': progressTotal,
    'location': location,
    'route': route,
  };
}

class DashboardSummary {
  final DashboardKpi kpi;
  final List<DashboardTaskItem> tasks;
  final bool isOnline;
  final String shiftName;
  final int pendingSyncCount;

  const DashboardSummary({
    this.kpi = const DashboardKpi(),
    this.tasks = const [],
    this.isOnline = true,
    this.shiftName = 'Shift 1 (Pagi) • 08:00 - 16:00',
    this.pendingSyncCount = 3,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'];
    final taskList = <DashboardTaskItem>[];
    if (rawTasks is List) {
      for (final t in rawTasks) {
        if (t is Map) {
          taskList.add(DashboardTaskItem.fromJson(Map<String, dynamic>.from(t)));
        }
      }
    }

    return DashboardSummary(
      kpi: json['kpi'] is Map
          ? DashboardKpi.fromJson(Map<String, dynamic>.from(json['kpi'] as Map))
          : const DashboardKpi(),
      tasks: taskList,
      isOnline: (json['is_online'] ?? json['isOnline'] ?? true) as bool,
      shiftName: json['shift_name']?.toString() ?? 'Shift 1 (Pagi) • 08:00 - 16:00',
      pendingSyncCount: (json['pending_sync_count'] ?? json['pendingSyncCount'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'kpi': kpi.toJson(),
    'tasks': tasks.map((e) => e.toJson()).toList(),
    'is_online': isOnline,
    'shift_name': shiftName,
    'pending_sync_count': pendingSyncCount,
  };

  DashboardSummary copyWith({
    DashboardKpi? kpi,
    List<DashboardTaskItem>? tasks,
    bool? isOnline,
    String? shiftName,
    int? pendingSyncCount,
  }) {
    return DashboardSummary(
      kpi: kpi ?? this.kpi,
      tasks: tasks ?? this.tasks,
      isOnline: isOnline ?? this.isOnline,
      shiftName: shiftName ?? this.shiftName,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
    );
  }
}
