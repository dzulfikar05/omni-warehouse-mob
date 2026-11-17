class StockOpnameItem {
  const StockOpnameItem({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.targetRack,
    required this.physicalQty,
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
  final int? skuId;
  final int? locationId;
  final String unit;

  StockOpnameItem copyWith({num? physicalQty}) => StockOpnameItem(
        id: id,
        sku: sku,
        barcode: barcode,
        name: name,
        targetRack: targetRack,
        physicalQty: physicalQty ?? this.physicalQty,
        skuId: skuId,
        locationId: locationId,
        unit: unit,
      );

  Map<String, dynamic> toJson() => {
        'item_id': id,
        if (skuId != null) 'sku_id': skuId,
        'sku_code': sku,
        'barcode': barcode,
        'product_name': name,
        if (locationId != null) 'location_id': locationId,
        'target_rack': targetRack,
        'physical_qty': physicalQty,
        'unit': unit,
      };

  factory StockOpnameItem.fromJson(Map<String, dynamic> json) {
    final skuMap = _asMap(json['sku']) ?? const <String, dynamic>{};
    final productMap = _asMap(json['product']) ?? const <String, dynamic>{};
    final locationMap = _asMap(
      json['location'] ?? json['target_location'] ?? json['rack'],
    );
    final rawSku = json['sku'] is String ? json['sku'] : null;
    return StockOpnameItem(
      id: _asInt(json['item_id'] ?? json['id']),
      sku: (json['sku_code'] ??
              json['sku_name'] ??
              rawSku ??
              skuMap['sku'] ??
              productMap['sku'] ??
              '')
          .toString(),
      barcode:
          (json['barcode'] ?? skuMap['barcode'] ?? productMap['barcode'] ?? '')
              .toString(),
      name: (json['product_name'] ??
              json['name'] ??
              skuMap['name'] ??
              productMap['name'] ??
              'Produk')
          .toString(),
      targetRack: (json['target_rack'] ??
              json['rack_code'] ??
              json['location_name'] ??
              locationMap?['rack_code'] ??
              locationMap?['name'] ??
              '')
          .toString(),
      physicalQty: _asNum(json['physical_qty']),
      skuId: _asNullableInt(json['sku_id'] ?? skuMap['id']),
      locationId: _asNullableInt(json['location_id'] ?? locationMap?['id']),
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
  final bool isOfflinePending;
  final bool isReviewPending;
  final String? syncError;

  int get countedItems =>
      items.where((item) => item.physicalQty != null).length;
  double get progress => items.isEmpty ? 0 : countedItems / items.length;
  bool get allItemsCounted => items.isNotEmpty && countedItems == items.length;
  bool get isInReview => status.toUpperCase() == 'REVIEW';

  StockOpnameSession copyWith({
    String? status,
    List<StockOpnameItem>? items,
    bool? isOfflinePending,
    bool? isReviewPending,
    String? syncError,
  }) =>
      StockOpnameSession(
        id: id,
        sessionCode: sessionCode,
        warehouse: warehouse,
        zone: zone,
        status: status ?? this.status,
        items: items ?? this.items,
        isOfflinePending: isOfflinePending ?? this.isOfflinePending,
        isReviewPending: isReviewPending ?? this.isReviewPending,
        syncError: syncError,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_code': sessionCode,
        'warehouse_name': warehouse,
        'zone_name': zone,
        'status': status,
        'items': items.map((item) => item.toJson()).toList(),
        'is_offline_pending': isOfflinePending,
        'is_review_pending': isReviewPending,
        'sync_error': syncError,
      };

  factory StockOpnameSession.fromJson(Map<String, dynamic> json) {
    final warehouseMap = _asMap(json['warehouse']);
    final zoneMap = _asMap(json['zone']);
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
      sessionCode: (json['session_code'] ??
              json['code'] ??
              json['reference_number'] ??
              '')
          .toString(),
      warehouse: (json['warehouse_name'] ??
              warehouseMap?['name'] ??
              json['warehouse'] ??
              '')
          .toString(),
      zone: (json['zone_name'] ??
              zoneMap?['name'] ??
              (json['zone'] is String ? json['zone'] : null) ??
              json['location_name'] ??
              '')
          .toString(),
      status: (json['status'] ?? 'ACTIVE').toString(),
      items: items,
      isOfflinePending: json['is_offline_pending'] == true,
      isReviewPending: json['is_review_pending'] == true,
      syncError: json['sync_error']?.toString(),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

int? _asNullableInt(dynamic value) =>
    value == null ? null : int.tryParse(value.toString());

num? _asNum(dynamic value) =>
    value == null ? null : num.tryParse(value.toString());
