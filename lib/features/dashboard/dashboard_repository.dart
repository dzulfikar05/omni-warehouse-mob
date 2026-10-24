import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_endpoints.dart';
import 'dashboard_model.dart';

abstract class DashboardRepository {
  DashboardSummary getInitialSummary();
  Future<DashboardSummary> getSummary();
  Future<void> syncOfflineQueue();
}

class MockDashboardRepository implements DashboardRepository {
  DashboardSummary _summary = const DashboardSummary(
    kpi: DashboardKpi(
      activeInboundCount: 4,
      activeOutboundCount: 2,
      pendingTransferCount: 4,
      activeOpnameCount: 1,
      offlineQueueCount: 3,
    ),
    isOnline: true,
    shiftName: 'Shift 1 (Pagi) • 08:00 - 16:00',
    pendingSyncCount: 3,
    tasks: [
      DashboardTaskItem(
        id: 'task-inbound-01',
        type: 'inbound',
        badgeLabel: 'RECEIVING',
        code: 'PO-2025-0891',
        title: 'PT Indah Logistik Mandiri',
        subtitle: 'Inbound Pallet • Dock Bay 04',
        progressCurrent: 170,
        progressTotal: 250,
        location: 'Dock Bay 04',
        route: '/inbound/PO-2025-0891',
      ),
      DashboardTaskItem(
        id: 'task-outbound-01',
        type: 'outbound',
        badgeLabel: 'PICKING',
        code: 'SO-2025-1102',
        title: 'Toko Berkah Retail Jaya',
        subtitle: 'Dispatch Reguler • Staging S-01',
        progressCurrent: 15,
        progressTotal: 50,
        location: 'Staging S-01',
        route: '/outbound/SO-2025-1102',
      ),
      DashboardTaskItem(
        id: 'task-transfer-01',
        type: 'transfer',
        badgeLabel: 'TRANSFER',
        code: 'TR-2026-0042',
        title: 'Transfer Rak Lorong B',
        subtitle: 'Kabel Fiber Optic Drop Core • 40 Roll',
        progressCurrent: 40,
        progressTotal: 40,
        location: 'RACK-B1-02 -> RACK-B3-04',
        route: '/more/transfer',
      ),
      DashboardTaskItem(
        id: 'task-opname-01',
        type: 'opname',
        badgeLabel: 'OPNAME',
        code: 'OP-2026-001',
        title: 'Audit Siklus Lorong A & B',
        subtitle: '15 / 24 SKU Terhitung Fisik',
        progressCurrent: 15,
        progressTotal: 24,
        location: 'Area Rak A & B',
        route: '/more/opname/OP-2026-001',
      ),
    ],
  );

  @override
  DashboardSummary getInitialSummary() => _summary;

  @override
  Future<DashboardSummary> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _summary;
  }

  @override
  Future<void> syncOfflineQueue() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _summary = _summary.copyWith(
      pendingSyncCount: 0,
      kpi: _summary.kpi.copyWith(offlineQueueCount: 0),
    );
  }
}

class ApiDashboardRepository implements DashboardRepository {
  final Dio _dio;

  ApiDashboardRepository(this._dio);

  @override
  DashboardSummary getInitialSummary() => const DashboardSummary();

  @override
  Future<DashboardSummary> getSummary() async {
    final response = await _dio.get(ApiEndpoints.dashboardSummary);
    final data = response.data;
    final itemMap = (data is Map && data['data'] is Map)
        ? data['data'] as Map
        : (data is Map ? data : null);
    if (itemMap == null) return const DashboardSummary();
    return DashboardSummary.fromJson(Map<String, dynamic>.from(itemMap));
  }

  @override
  Future<void> syncOfflineQueue() async {
    // Panggil sync endpoint Laravel
  }
}

final dashboardDataSourceProvider = Provider<DashboardRepository>((ref) {
  return MockDashboardRepository();
  // return ApiDashboardRepository(ref.watch(dioProvider));
});

class DashboardNotifier extends StateNotifier<DashboardSummary> {
  final DashboardRepository _repository;

  DashboardNotifier(this._repository) : super(_repository.getInitialSummary());

  Future<void> refresh() async {
    final res = await _repository.getSummary();
    state = res;
  }

  Future<void> syncOfflineQueue() async {
    await _repository.syncOfflineQueue();
    state = state.copyWith(
      pendingSyncCount: 0,
      kpi: state.kpi.copyWith(offlineQueueCount: 0),
    );
  }
}

final dashboardNotifierProvider =
    StateNotifierProvider<DashboardNotifier, DashboardSummary>((ref) {
  final repo = ref.watch(dashboardDataSourceProvider);
  return DashboardNotifier(repo);
});
