class StockOpnameItem {
  const StockOpnameItem({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.targetRack,
    required this.physicalQty,
    this.locationLabel = '',
    this.skuId,
    this.locationId,
    this.unit = 'pcs',
  });

  final int id;
  final String sku;
  final String barcode;
  final String name;
  final String targetRack;
  final num? physicalQty;
  final String locationLabel;
  final int? skuId;
  final int? locationId;
  final String unit;

  StockOpnameItem copyWith({
    num? physicalQty,
    int? locationId,
    String? targetRack,
  }) => StockOpnameItem(
    id: id,
    sku: sku,
    barcode: barcode,
    name: name,
    targetRack: targetRack ?? this.targetRack,
    physicalQty: physicalQty ?? this.physicalQty,
    skuId: skuId,
    locationId: locationId ?? this.locationId,
    locationLabel: locationLabel,
    unit: unit,
  );

  Map<String, dynamic> toJson() => {
    'item_id': id,
    if (skuId != null) 'sku_id': skuId,
    'sku_code': sku,
    'barcode': barcode,
    'product_name': name,
    if (locationId != null) 'location_id': locationId,
    if (locationLabel.isNotEmpty) 'location_label': locationLabel,
    'target_rack': targetRack,
    'physical_qty': physicalQty,
    'unit': unit,
  };

  factory StockOpnameItem.fromJson(Map<String, dynamic> json) {
    final skuMap = _asMap(json['sku']) ?? const <String, dynamic>{};
    final productMap = _asMap(json['product']) ?? const <String, dynamic>{};
    final locationMap = _asMap(json['location'] ?? json['target_location']);
    final rackMap = _asMap(json['rack']);
    final rawSku = json['sku'] is String ? json['sku'] : null;
    return StockOpnameItem(
      id: _asInt(json['item_id'] ?? json['id']),
      sku:
          (json['sku_code'] ??
                  json['sku_name'] ??
                  rawSku ??
                  skuMap['sku'] ??
                  productMap['sku'] ??
                  '')
              .toString(),
      barcode:
          (json['barcode'] ?? skuMap['barcode'] ?? productMap['barcode'] ?? '')
              .toString(),
      name:
          (json['product_name'] ??
                  json['name'] ??
                  skuMap['name'] ??
                  productMap['name'] ??
                  'Produk')
              .toString(),
      targetRack:
          (json['target_rack'] ??
                  json['rack_code'] ??
                  rackMap?['rack_code'] ??
                  rackMap?['code'] ??
                  rackMap?['name'] ??
                  locationMap?['rack_code'] ??
                  locationMap?['code'] ??
                  '')
              .toString(),
      locationLabel: (json['location_label'] ?? locationMap?['name'] ?? '')
          .toString(),
      physicalQty: _asNum(json['physical_qty']),
      skuId: _asNullableInt(json['sku_id'] ?? skuMap['id']),
      locationId: _asNullableInt(
        json['location_id'] ?? locationMap?['id'] ?? rackMap?['id'],
      ),
      unit: (json['unit'] ?? json['unit_name'] ?? 'pcs').toString(),
    );
  }
}

class StockOpnameSession {
  const StockOpnameSession({
    required this.id,
    required this.sessionCode,
    required this.warehouse,
    required this.zone,
    required this.status,
    required this.items,
    this.locationId,
    this.locationLabel = '',
    this.isOfflinePending = false,
    this.isReviewPending = false,
    this.syncError,
  });

  final int id;
  final String sessionCode;
  final String warehouse;
  final String zone;
  final String status;
  final List<StockOpnameItem> items;
  final int? locationId;
  final String locationLabel;
  final bool isOfflinePending;
  final bool isReviewPending;
  final String? syncError;

  int get countedItems =>
      items.where((item) => item.physicalQty != null).length;
  double get progress => items.isEmpty ? 0 : countedItems / items.length;
  bool get allItemsCounted => items.isNotEmpty && countedItems == items.length;
  bool get isInReview => status.toUpperCase() == 'REVIEW';
  bool get isClosedOrAdjusted =>
      const {'CLOSED', 'ADJUSTED'}.contains(status.toUpperCase());
  bool get isReadOnly =>
      isInReview || const {'ADJUSTED', 'CLOSED'}.contains(status.toUpperCase());
  bool get canCount =>
      const {'DRAFT', 'COUNTING', 'ACTIVE'}.contains(status.toUpperCase()) &&
      !isReviewPending;
  bool get canSubmitReview =>
      const {'DRAFT', 'COUNTING', 'ACTIVE'}.contains(status.toUpperCase());

  StockOpnameSession copyWith({
    String? status,
    List<StockOpnameItem>? items,
    bool? isOfflinePending,
    bool? isReviewPending,
    String? syncError,
  }) => StockOpnameSession(
    id: id,
    sessionCode: sessionCode,
    warehouse: warehouse,
    zone: zone,
    status: status ?? this.status,
    items: items ?? this.items,
    locationId: locationId,
    locationLabel: locationLabel,
    isOfflinePending: isOfflinePending ?? this.isOfflinePending,
    isReviewPending: isReviewPending ?? this.isReviewPending,
    syncError: syncError,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_code': sessionCode,
    'warehouse_name': warehouse,
    'zone_name': zone,
    'location_id': locationId,
    'location_label': locationLabel,
    'status': status,
    'items': items.map((item) => item.toJson()).toList(),
    'is_offline_pending': isOfflinePending,
    'is_review_pending': isReviewPending,
    'sync_error': syncError,
  };

  factory StockOpnameSession.fromJson(Map<String, dynamic> json) {
    final warehouseMap = _asMap(json['warehouse']);
    final zoneMap = _asMap(json['zone']);
    final locationMap = _asMap(json['location']);
    final rawItems = json['items'] ?? json['details'] ?? json['session_items'];
    final itemList = rawItems is Map ? rawItems['data'] : rawItems;
    final items = itemList is List
        ? itemList
              .whereType<Map>()
              .map(
                (item) =>
                    StockOpnameItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <StockOpnameItem>[];

    return StockOpnameSession(
      id: _asInt(json['session_id'] ?? json['id']),
      sessionCode:
          (json['session_code'] ??
                  json['code'] ??
                  json['reference_number'] ??
                  '')
              .toString(),
      warehouse:
          (json['warehouse_name'] ??
                  warehouseMap?['name'] ??
                  json['warehouse'] ??
                  '')
              .toString(),
      zone:
          (json['zone_name'] ??
                  zoneMap?['name'] ??
                  (json['zone'] is String ? json['zone'] : null) ??
                  json['location_name'] ??
                  '')
              .toString(),
      status: (json['status'] ?? 'ACTIVE').toString(),
      items: items,
      locationId: _asNullableInt(json['location_id'] ?? locationMap?['id']),
      locationLabel: (json['location_label'] ?? locationMap?['name'] ?? '')
          .toString(),
      isOfflinePending: json['is_offline_pending'] == true,
      isReviewPending: json['is_review_pending'] == true,
      syncError: json['sync_error']?.toString(),
    );
  }
}

class StockOpnameSessionSummary {
  const StockOpnameSessionSummary({
    required this.id,
    required this.sessionCode,
    required this.status,
    required this.warehouseName,
    required this.warehouseCode,
    required this.locationId,
    required this.locationLabel,
    required this.auditorName,
    required this.createdAt,
    required this.totalItems,
    required this.countedItems,
  });

  final int id;
  final String sessionCode;
  final String status;
  final String warehouseName;
  final String warehouseCode;
  final int? locationId;
  final String locationLabel;
  final String auditorName;
  final String createdAt;
  final int totalItems;
  final int countedItems;

  double get progress => totalItems == 0 ? 0 : countedItems / totalItems;

  factory StockOpnameSessionSummary.fromJson(Map<String, dynamic> json) =>
      StockOpnameSessionSummary(
        id: _asInt(json['id'] ?? json['session_id']),
        sessionCode: (json['session_code'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        warehouseName: (json['warehouse_name'] ?? '').toString(),
        warehouseCode: (json['warehouse_code'] ?? '').toString(),
        locationId: _asNullableInt(json['location_id']),
        locationLabel: (json['location_label'] ?? 'Semua lokasi').toString(),
        auditorName: (json['auditor_name'] ?? '').toString(),
        createdAt: (json['created_at'] ?? '').toString(),
        totalItems: _asInt(json['total_items']),
        countedItems: _asInt(json['counted_items']),
      );
}

class StockOpnameSessionPage {
  const StockOpnameSessionPage({
    required this.sessions,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.isOfflineSnapshot = false,
  });

  final List<StockOpnameSessionSummary> sessions;
  final int currentPage;
  final int lastPage;
  final int total;
  final bool isOfflineSnapshot;

  bool get hasMore => currentPage < lastPage;
}

Map<String, dynamic>? _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

int? _asNullableInt(dynamic value) =>
    value == null ? null : int.tryParse(value.toString());

num? _asNum(dynamic value) =>
    value == null ? null : num.tryParse(value.toString());
