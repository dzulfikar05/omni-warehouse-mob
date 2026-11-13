class StockOpnameItem {
  const StockOpnameItem({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.targetRack,
    required this.physicalQty,
    this.unit = 'pcs',
  });

  final int id;
  final String sku;
  final String barcode;
  final String name;
  final String targetRack;
  final num? physicalQty;
  final String unit;

  StockOpnameItem copyWith({num? physicalQty}) => StockOpnameItem(
    id: id,
    sku: sku,
    barcode: barcode,
    name: name,
    targetRack: targetRack,
    physicalQty: physicalQty ?? this.physicalQty,
    unit: unit,
  );

  factory StockOpnameItem.fromJson(Map<String, dynamic> json) {
    final skuMap = _asMap(json['sku']) ?? const <String, dynamic>{};
    final productMap = _asMap(json['product']) ?? const <String, dynamic>{};
    final locationMap = _asMap(
      json['location'] ?? json['target_location'] ?? json['rack'],
    );
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
                  json['location_name'] ??
                  locationMap?['rack_code'] ??
                  locationMap?['name'] ??
                  '')
              .toString(),
      physicalQty: _asNum(json['physical_qty']),
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
  });

  final int id;
  final String sessionCode;
  final String warehouse;
  final String zone;
  final String status;
  final List<StockOpnameItem> items;

  int get countedItems =>
      items.where((item) => item.physicalQty != null).length;
  double get progress => items.isEmpty ? 0 : countedItems / items.length;
  bool get allItemsCounted => items.isNotEmpty && countedItems == items.length;
  bool get isInReview => status.toUpperCase() == 'REVIEW';

  StockOpnameSession copyWith({String? status, List<StockOpnameItem>? items}) =>
      StockOpnameSession(
        id: id,
        sessionCode: sessionCode,
        warehouse: warehouse,
        zone: zone,
        status: status ?? this.status,
        items: items ?? this.items,
      );

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
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

num? _asNum(dynamic value) =>
    value == null ? null : num.tryParse(value.toString());
