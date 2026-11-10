class TransferMasterOptions {
  const TransferMasterOptions({
    required this.warehouses,
    required this.locations,
    required this.skus,
  });

  final List<TransferWarehouse> warehouses;
  final List<TransferLocation> locations;
  final List<TransferSku> skus;
}

class TransferWarehouse {
  const TransferWarehouse({required this.id, required this.name});

  final int id;
  final String name;

  factory TransferWarehouse.fromJson(Map<String, dynamic> json) =>
      TransferWarehouse(
        id: _asInt(json['id']),
        name: (json['name'] ?? json['warehouse_name'] ?? '').toString(),
      );
}

class TransferLocation {
  const TransferLocation({
    required this.id,
    required this.name,
    this.warehouseId,
    this.warehouseName,
  });

  final int id;
  final String name;
  final int? warehouseId;
  final String? warehouseName;

  factory TransferLocation.fromJson(Map<String, dynamic> json) {
    final warehouse = _asMap(json['warehouse']);
    return TransferLocation(
      id: _asInt(json['id']),
      name: (json['rack_code'] ??
              json['location_code'] ??
              json['name'] ??
              json['code'] ??
              '')
          .toString(),
      warehouseId: _asNullableInt(
        json['warehouse_id'] ?? warehouse?['id'],
      ),
      warehouseName: (json['warehouse_name'] ?? warehouse?['name'])?.toString(),
    );
  }
}

class TransferSku {
  const TransferSku({
    required this.id,
    required this.code,
    required this.name,
    this.barcode = '',
    this.availableStock,
    this.unit = 'pcs',
  });

  final int id;
  final String code;
  final String name;
  final String barcode;
  final int? availableStock;
  final String unit;

  factory TransferSku.fromJson(Map<String, dynamic> json) {
    final product = _asMap(json['product']) ?? const <String, dynamic>{};
    final rawStock = json['available_stock'] ??
        json['available_quantity'] ??
        json['stock_available'] ??
        json['stock'] ??
        json['quantity_available'];
    return TransferSku(
      id: _asInt(json['sku_id'] ?? json['id']),
      code:
          (json['sku'] ?? json['sku_code'] ?? product['sku'] ?? '').toString(),
      name: (json['name'] ?? json['product_name'] ?? product['name'] ?? '')
          .toString(),
      barcode: (json['barcode'] ?? product['barcode'] ?? '').toString(),
      availableStock: rawStock == null ? null : _asInt(rawStock),
      unit: (json['unit'] ?? json['unit_name'] ?? 'pcs').toString(),
    );
  }

  String get label => code.isEmpty ? name : '$name ($code)';
}

class TransferTransactionLine {
  const TransferTransactionLine({
    required this.skuId,
    required this.sku,
    required this.productName,
    required this.fromLocation,
    required this.toLocation,
    required this.quantity,
    this.fromLocationId,
    this.toLocationId,
    this.batchNumber,
    this.expiryDate,
    this.unit = 'pcs',
  });

  final int skuId;
  final String sku;
  final String productName;
  final String fromLocation;
  final String toLocation;
  final int quantity;
  final int? fromLocationId;
  final int? toLocationId;
  final String? batchNumber;
  final String? expiryDate;
  final String unit;

  factory TransferTransactionLine.fromJson(Map<String, dynamic> json) {
    final skuObject = _asMap(json['sku']) ?? const <String, dynamic>{};
    final product = _asMap(json['product']) ?? const <String, dynamic>{};
    final from = _asMap(json['from_location'] ?? json['source_location']);
    final to = _asMap(json['to_location'] ?? json['destination_location']);
    return TransferTransactionLine(
      skuId: _asInt(json['sku_id'] ?? skuObject['id']),
      sku: (json['sku_code'] ??
              json['sku_name'] ??
              (json['sku'] is String ? json['sku'] : null) ??
              skuObject['sku'] ??
              product['sku'] ??
              '')
          .toString(),
      productName: (json['product_name'] ??
              json['name'] ??
              skuObject['name'] ??
              product['name'] ??
              'Produk')
          .toString(),
      fromLocation: (json['from_location_name'] ??
              json['source_location_name'] ??
              from?['rack_code'] ??
              from?['name'] ??
              (json['from_location'] is String
                  ? json['from_location']
                  : null) ??
              '')
          .toString(),
      toLocation: (json['to_location_name'] ??
              json['destination_location_name'] ??
              to?['rack_code'] ??
              to?['name'] ??
              (json['to_location'] is String ? json['to_location'] : null) ??
              '')
          .toString(),
      quantity: _asInt(json['quantity'] ?? json['qty']),
      fromLocationId: _asNullableInt(
        json['from_location_id'] ?? from?['id'],
      ),
      toLocationId: _asNullableInt(json['to_location_id'] ?? to?['id']),
      batchNumber: json['batch_number']?.toString(),
      expiryDate: json['expiry_date']?.toString(),
      unit: (json['unit'] ?? 'pcs').toString(),
    );
  }
}

class TransferTransaction {
  const TransferTransaction({
    required this.code,
    required this.status,
    required this.createdAt,
    required this.items,
    this.creator = '',
    this.notes,
    this.itemCount,
    this.totalQuantity,
  });

  final String code;
  final String status;
  final String createdAt;
  final List<TransferTransactionLine> items;
  final String creator;
  final String? notes;
  final int? itemCount;
  final int? totalQuantity;

  int get totalItems => itemCount ?? items.length;
  int get units =>
      totalQuantity ?? items.fold(0, (total, item) => total + item.quantity);
  bool get canCancel =>
      status.toLowerCase() != 'cancelled' && status.toLowerCase() != 'canceled';
  bool get isEditable =>
      status.toLowerCase() == 'draft' || status.toLowerCase() == 'pending';

  factory TransferTransaction.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] ?? json['details'] ?? json['lines'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (item) => TransferTransactionLine.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <TransferTransactionLine>[];
    final user = _asMap(json['creator'] ?? json['user']);
    return TransferTransaction(
      code: (json['transfer_code'] ??
              json['reference_number'] ??
              json['code'] ??
              json['transaction_code'] ??
              '')
          .toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      items: items,
      creator: (json['created_by_name'] ??
              json['operator_name'] ??
              user?['name'] ??
              '')
          .toString(),
      notes: json['notes']?.toString(),
      itemCount: _asNullableInt(
        json['total_items'] ?? json['item_count'] ?? json['total_skus'],
      ),
      totalQuantity: _asNullableInt(
        json['total_quantity'] ?? json['total_units'] ?? json['total_qty'],
      ),
    );
  }
}

class TransferTransactionStats {
  const TransferTransactionStats({
    required this.total,
    required this.inProgress,
    required this.completed,
    required this.totalUnits,
  });

  final int total;
  final int inProgress;
  final int completed;
  final int totalUnits;

  factory TransferTransactionStats.fromJson(
    Map<String, dynamic> json, {
    required List<TransferTransaction> transactions,
  }) {
    if (json.isNotEmpty) {
      return TransferTransactionStats(
        total: _asInt(json['total'] ?? json['total_transactions']),
        inProgress: _asInt(json['in_progress'] ?? json['pending']),
        completed: _asInt(json['completed']),
        totalUnits: _asInt(json['total_units'] ?? json['total_quantity']),
      );
    }
    return TransferTransactionStats(
      total: transactions.length,
      inProgress: transactions
          .where((item) => item.status.toLowerCase() == 'pending')
          .length,
      completed: transactions
          .where((item) => item.status.toLowerCase() == 'completed')
          .length,
      totalUnits: transactions.fold(0, (sum, item) => sum + item.units),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

int? _asNullableInt(dynamic value) =>
    value == null ? null : int.tryParse(value.toString());
