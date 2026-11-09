import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum OutboundStatus {
  readyToPick,
  picking,
  packing,
  dispatched,
  hold;

  String get label => switch (this) {
    OutboundStatus.readyToPick => 'SIAP PICKING',
    OutboundStatus.picking => 'PICKING',
    OutboundStatus.packing => 'PACKING',
    OutboundStatus.dispatched => 'DISPATCHED',
    OutboundStatus.hold => 'HOLD',
  };

  static OutboundStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'PICKING':
      case 'IN_PROGRESS':
      case 'PROCESSING':
        return OutboundStatus.picking;
      case 'PACKING':
      case 'READY_TO_DISPATCH':
        return OutboundStatus.packing;
      case 'DISPATCHED':
      case 'COMPLETED':
      case 'CLOSED':
      case 'COMMITTED':
      case 'SUCCESS':
        return OutboundStatus.dispatched;
      case 'HOLD':
      case 'ON_HOLD':
        return OutboundStatus.hold;
      case 'READY':
      case 'READY_TO_PICK':
      case 'DRAFT':
      case 'PENDING':
      default:
        return OutboundStatus.readyToPick;
    }
  }

  Color get color => switch (this) {
    OutboundStatus.readyToPick => AppColors.primary,
    OutboundStatus.picking => const Color(0xFFD97706),
    OutboundStatus.packing => const Color(0xFF7C3AED),
    OutboundStatus.dispatched => AppColors.success,
    OutboundStatus.hold => AppColors.danger,
  };

  Color get bg => switch (this) {
    OutboundStatus.readyToPick => AppColors.primaryLight,
    OutboundStatus.picking => AppColors.warningLight,
    OutboundStatus.packing => const Color(0xFFF5F3FF),
    OutboundStatus.dispatched => AppColors.successLight,
    OutboundStatus.hold => AppColors.dangerLight,
  };

  Color get border => switch (this) {
    OutboundStatus.readyToPick => AppColors.primaryBorder,
    OutboundStatus.picking => AppColors.warningBorder,
    OutboundStatus.packing => const Color(0xFFDDD6FE),
    OutboundStatus.dispatched => AppColors.successBorder,
    OutboundStatus.hold => AppColors.dangerBorder,
  };
}

class OutboundCustomer {
  const OutboundCustomer({
    required this.id,
    required this.name,
    this.code = '',
  });

  final int id;
  final String name;
  final String code;

  factory OutboundCustomer.fromJson(Map<String, dynamic> json) =>
      OutboundCustomer(
        id: _asInt(json['id']),
        name: (json['name'] ?? json['customer_name'] ?? '').toString(),
        code: (json['code'] ?? json['customer_code'] ?? '').toString(),
      );
}

class OutboundProductMaster {
  const OutboundProductMaster({
    required this.skuId,
    required this.sku,
    required this.barcode,
    required this.name,
    this.productId = 0,
  });

  final int skuId;
  final int productId;
  final String sku;
  final String barcode;
  final String name;

  factory OutboundProductMaster.fromJson(Map<String, dynamic> json) {
    final product = json['product'] is Map
        ? Map<String, dynamic>.from(json['product'] as Map)
        : const <String, dynamic>{};
    return OutboundProductMaster(
      skuId: _asInt(json['sku_id'] ?? json['id']),
      productId: _asInt(json['product_id'] ?? product['id']),
      sku: (json['sku'] ?? product['sku'] ?? '').toString(),
      barcode: (json['barcode'] ?? product['barcode'] ?? '').toString(),
      name: (json['name'] ?? json['product_name'] ?? product['name'] ?? '')
          .toString(),
    );
  }
}

class OutboundLocation {
  const OutboundLocation({required this.id, required this.rackCode, this.zone});

  final int id;
  final String rackCode;
  final String? zone;

  factory OutboundLocation.fromJson(Map<String, dynamic> json) =>
      OutboundLocation(
        id: _asInt(json['id']),
        rackCode: (json['rack_code'] ?? json['code'] ?? '').toString(),
        zone: json['zone']?.toString(),
      );
}

class OutboundItem {
  OutboundItem({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.fromRack,
    required this.orderQty,
    this.skuId = 0,
    this.pickedQty = 0,
    this.damagedQty = 0,
    this.packedQty = 0,
    this.sourceRackId,
    this.unit = 'Pcs',
    this.category = 'Umum',
    this.notes,
  });

  final String id;
  final String sku;
  final String barcode;
  final String name;
  final String fromRack;
  final int orderQty;
  final int skuId;
  int pickedQty;
  int damagedQty;
  int packedQty;
  final int? sourceRackId;
  final String unit;
  final String category;
  String? notes;

  bool get isFullyPicked => pickedQty >= orderQty;
  int get totalProcessedQty => pickedQty + damagedQty;
  bool get isFullyPacked => packedQty >= orderQty;
  int get remainingToPick => (orderQty - pickedQty).clamp(0, orderQty);

  factory OutboundItem.fromJson(Map<String, dynamic> json) {
    final skuMap = json['sku'] is Map
        ? Map<String, dynamic>.from(json['sku'] as Map)
        : const <String, dynamic>{};
    final productMap = json['product'] is Map
        ? Map<String, dynamic>.from(json['product'] as Map)
        : const <String, dynamic>{};
    final locationMap = json['location'] is Map
        ? Map<String, dynamic>.from(json['location'] as Map)
        : const <String, dynamic>{};
    final rackId =
        json['source_rack_id'] ?? json['location_id'] ?? locationMap['id'];
    return OutboundItem(
      id: (json['id'] ?? json['item_id'] ?? '').toString(),
      sku:
          (json['sku_code'] ??
                  json['sku_name'] ??
                  (json['sku'] is String ? json['sku'] : null) ??
                  skuMap['sku'] ??
                  productMap['sku'] ??
                  '')
              .toString(),
      barcode: (json['barcode'] ?? skuMap['barcode'] ?? '').toString(),
      name:
          (json['product_name'] ??
                  json['name'] ??
                  skuMap['name'] ??
                  productMap['name'] ??
                  'Barang Outbound')
              .toString(),
      fromRack:
          (json['source_rack'] ??
                  json['rack_code'] ??
                  locationMap['rack_code'] ??
                  '')
              .toString(),
      orderQty: _asInt(json['so_qty'] ?? json['order_qty'] ?? json['quantity']),
      skuId: _asInt(json['sku_id'] ?? skuMap['id']),
      pickedQty: _asInt(json['good_qty'] ?? json['picked_qty']),
      damagedQty: _asInt(json['damaged_qty']),
      packedQty: _asInt(json['packed_qty']),
      sourceRackId: rackId == null ? null : _asInt(rackId),
      unit: (json['unit'] ?? 'Pcs').toString(),
      category: (json['category'] ?? 'Umum').toString(),
      notes: (json['damage_note'] ?? json['notes'])?.toString(),
    );
  }

  OutboundItem copyWith({
    String? id,
    String? sku,
    String? barcode,
    String? name,
    String? fromRack,
    int? orderQty,
    int? skuId,
    int? pickedQty,
    int? damagedQty,
    int? packedQty,
    int? sourceRackId,
    String? unit,
    String? category,
    String? notes,
  }) {
    return OutboundItem(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      fromRack: fromRack ?? this.fromRack,
      orderQty: orderQty ?? this.orderQty,
      skuId: skuId ?? this.skuId,
      pickedQty: pickedQty ?? this.pickedQty,
      damagedQty: damagedQty ?? this.damagedQty,
      packedQty: packedQty ?? this.packedQty,
      sourceRackId: sourceRackId ?? this.sourceRackId,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      notes: notes ?? this.notes,
    );
  }
}

class OutboundOrder {
  OutboundOrder({
    required this.code,
    required this.customer,
    required this.destination,
    required this.expedition,
    required this.stagingBay,
    required this.status,
    required this.items,
    this.customerId = 0,
    this.vehicleNo,
    this.driverName,
    this.notes,
    this.totalUnits,
    this.totalSkus,
    this.waveId,
    this.startedAt,
    this.dispatchedAt,
    this.trackingNumber,
  });

  final String code;
  final String customer;
  final int customerId;
  final String? vehicleNo;
  final String? driverName;
  final String? notes;
  final int? totalUnits;
  final int? totalSkus;
  final String destination;
  final String expedition;
  final String stagingBay;
  OutboundStatus status;
  final List<OutboundItem> items;
  final String? waveId;
  final String? startedAt;
  final String? dispatchedAt;
  final String? trackingNumber;

  int get totalOrderUnits =>
      totalUnits ?? items.fold(0, (sum, it) => sum + it.orderQty);
  int get totalSkuCount => totalSkus ?? items.length;
  int get totalPickedUnits => items.fold(0, (sum, it) => sum + it.pickedQty);
  int get totalProcessedUnits =>
      items.fold(0, (sum, it) => sum + it.totalProcessedQty);
  int get totalPackedUnits => items.fold(0, (sum, it) => sum + it.packedQty);

  double get progressPercentage {
    if (totalOrderUnits == 0) return 0.0;
    return (totalProcessedUnits / totalOrderUnits).clamp(0.0, 1.0);
  }

  bool get isFullyPicked => totalProcessedUnits >= totalOrderUnits;
  bool get isFullyDispatched => status == OutboundStatus.dispatched;

  OutboundOrder copyWithItems(
    List<OutboundItem> updatedItems, {
    OutboundStatus? status,
    String? dispatchedAt,
  }) => OutboundOrder(
    code: code,
    customer: customer,
    customerId: customerId,
    vehicleNo: vehicleNo,
    driverName: driverName,
    notes: notes,
    totalUnits: totalUnits,
    totalSkus: totalSkus,
    destination: destination,
    expedition: expedition,
    stagingBay: stagingBay,
    status: status ?? this.status,
    items: updatedItems,
    waveId: waveId,
    startedAt: startedAt,
    dispatchedAt: dispatchedAt ?? this.dispatchedAt,
    trackingNumber: trackingNumber,
  );

  factory OutboundOrder.fromJson(Map<String, dynamic> json) {
    final customerMap = json['customer'] is Map
        ? Map<String, dynamic>.from(json['customer'] as Map)
        : const <String, dynamic>{};
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) =>
                    OutboundItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <OutboundItem>[];
    final status = OutboundStatus.fromString(json['status']?.toString());
    return OutboundOrder(
      code: (json['manifest_code'] ?? json['code'] ?? '').toString(),
      customer:
          (customerMap['name'] ??
                  json['customer_name'] ??
                  json['customer'] ??
                  'Customer')
              .toString(),
      customerId: _asInt(json['customer_id'] ?? customerMap['id']),
      vehicleNo: json['vehicle_no']?.toString(),
      driverName: json['driver_name']?.toString(),
      notes: json['notes']?.toString(),
      totalUnits: json['total_units'] == null
          ? null
          : _asInt(json['total_units']),
      totalSkus: json['total_skus'] == null && json['total_sku'] == null
          ? null
          : _asInt(json['total_skus'] ?? json['total_sku']),
      destination: (json['destination'] ?? json['shipping_address'] ?? '')
          .toString(),
      expedition:
          (json['expedition'] ?? json['courier'] ?? json['vehicle_no'] ?? '')
              .toString(),
      stagingBay: (json['staging_bay'] ?? json['staging_location'] ?? '-')
          .toString(),
      status: status,
      items: items,
      waveId: (json['wave_id'] ?? json['so_number'])?.toString(),
      startedAt: (json['started_at'] ?? json['created_at'])?.toString(),
      dispatchedAt: json['dispatched_at']?.toString(),
      trackingNumber: (json['tracking_number'] ?? json['tracking_no'])
          ?.toString(),
    );
  }
}

class OutboundManifestDetail {
  const OutboundManifestDetail({
    required this.manifest,
    required this.items,
    required this.locations,
  });

  final OutboundOrder manifest;
  final List<OutboundItem> items;
  final List<OutboundLocation> locations;
}

class OutboundStats {
  const OutboundStats({
    required this.todayTotal,
    required this.picking,
    required this.readyToDispatch,
    required this.dispatched,
  });

  final int todayTotal;
  final int picking;
  final int readyToDispatch;
  final int dispatched;

  factory OutboundStats.fromManifests(List<OutboundOrder> manifests) =>
      OutboundStats(
        todayTotal: manifests.length,
        picking: manifests
            .where(
              (order) =>
                  order.status == OutboundStatus.picking ||
                  order.status == OutboundStatus.readyToPick,
            )
            .length,
        readyToDispatch: manifests
            .where((order) => order.status == OutboundStatus.packing)
            .length,
        dispatched: manifests
            .where((order) => order.status == OutboundStatus.dispatched)
            .length,
      );

  factory OutboundStats.fromJson(
    Map<String, dynamic> json, {
    required List<OutboundOrder> manifests,
  }) {
    int number(List<String> keys, int fallback) {
      for (final key in keys) {
        final value = int.tryParse(json[key]?.toString() ?? '');
        if (value != null) return value;
      }
      return fallback;
    }

    final fallback = OutboundStats.fromManifests(manifests);
    return OutboundStats(
      todayTotal: number([
        'total',
        'today_total',
        'today',
      ], fallback.todayTotal),
      picking: number(['picking', 'in_progress'], fallback.picking),
      readyToDispatch: number([
        'ready_to_dispatch',
        'packing',
      ], fallback.readyToDispatch),
      dispatched: number(['dispatched', 'completed'], fallback.dispatched),
    );
  }
}

int _asInt(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
