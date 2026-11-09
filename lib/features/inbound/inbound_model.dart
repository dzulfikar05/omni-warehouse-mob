import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum InboundStatus {
  receiving,
  draft,
  closed,
  hold;

  String get label {
    switch (this) {
      case InboundStatus.receiving:
        return 'RECEIVING';
      case InboundStatus.draft:
        return 'DRAFT';
      case InboundStatus.closed:
        return 'CLOSED';
      case InboundStatus.hold:
        return 'ON HOLD';
    }
  }

  static InboundStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'RECEIVING':
      case 'IN_PROGRESS':
      case 'PROCESS':
      case 'PROSES':
        return InboundStatus.receiving;
      case 'CLOSED':
      case 'COMPLETED':
      case 'COMMITTED':
      case 'SUCCESS':
        return InboundStatus.closed;
      case 'HOLD':
      case 'ON_HOLD':
        return InboundStatus.hold;
      case 'DRAFT':
      case 'PENDING':
      default:
        return InboundStatus.draft;
    }
  }

  Color get color {
    switch (this) {
      case InboundStatus.receiving:
        return AppColors.warning;
      case InboundStatus.draft:
        return AppColors.primary;
      case InboundStatus.closed:
        return AppColors.success;
      case InboundStatus.hold:
        return AppColors.danger;
    }
  }

  Color get bg {
    switch (this) {
      case InboundStatus.receiving:
        return AppColors.warningLight;
      case InboundStatus.draft:
        return AppColors.primaryLight;
      case InboundStatus.closed:
        return AppColors.successLight;
      case InboundStatus.hold:
        return AppColors.dangerLight;
    }
  }
}

class InboundSupplier {
  final int id;
  final String code;
  final String name;

  InboundSupplier({required this.id, required this.code, required this.name});

  factory InboundSupplier.fromJson(Map<String, dynamic> json) {
    return InboundSupplier(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      code: json['code']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class InboundProductMaster {
  final int id; // SKU ID untuk transaction_items.sku_id
  final int productId; // Product Header ID
  final String sku;
  final String barcode;
  final String name;

  InboundProductMaster({
    required this.id,
    required this.productId,
    required this.sku,
    required this.barcode,
    required this.name,
  });

  factory InboundProductMaster.fromJson(Map<String, dynamic> json) {
    return InboundProductMaster(
      id: int.tryParse((json['sku_id'] ?? json['id'])?.toString() ?? '') ?? 0,
      productId: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? json['sku']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class InboundItem {
  InboundItem({
    required this.id,
    required this.productId,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.expectedQty,
    this.goodQty = 0,
    this.damagedQty = 0,
    this.targetRack,
    this.notes,
  });

  final String id;
  final int productId;
  final String sku;
  final String barcode;
  final String name;
  final int expectedQty;
  int goodQty;
  int damagedQty;
  String? targetRack;
  String? notes;

  int get totalScanned => goodQty + damagedQty;
  bool get isCompleted => totalScanned >= expectedQty;
  int get remaining => (expectedQty - totalScanned).clamp(0, expectedQty);

  factory InboundItem.fromJson(Map<String, dynamic> json) {
    final productMap = json['product'] is Map ? json['product'] : null;

    return InboundItem(
      id: json['id']?.toString() ?? '',
      productId:
          int.tryParse(
            (json['sku_id'] ?? json['product_id'] ?? productMap?['id'] ?? '')
                .toString(),
          ) ??
          0,
      sku: json['sku']?.toString() ?? productMap?['sku']?.toString() ?? '',
      barcode:
          json['barcode']?.toString() ??
          productMap?['barcode']?.toString() ??
          '',
      name:
          json['product_name']?.toString() ??
          json['name']?.toString() ??
          productMap?['name']?.toString() ??
          'Barang Inbound',
      expectedQty: _asInt(
        json['expected_qty'] ?? json['po_qty'] ?? json['expectedQty'],
      ),
      goodQty: _asInt(json['good_qty'] ?? json['goodQty']),
      damagedQty: _asInt(json['damaged_qty'] ?? json['damagedQty']),
      targetRack:
          json['target_rack']?.toString() ??
          (json['location'] is Map
              ? json['location']['rack_code']?.toString()
              : null),
      notes: json['damage_note']?.toString() ?? json['notes']?.toString(),
    );
  }

  static int _asInt(dynamic value) =>
      int.tryParse(value?.toString() ?? '') ?? 0;
}

class InboundManifest {
  InboundManifest({
    required this.code,
    required this.supplierId,
    required this.supplierName,
    required this.totalUnits,
    required this.status,
    required this.items,
    this.totalSkus = 0,
  });

  final String code;
  final int supplierId;
  final String supplierName;
  final int totalUnits;
  InboundStatus status;
  final List<InboundItem> items;
  final int totalSkus;

  factory InboundManifest.fromJson(Map<String, dynamic> json) {
    final supplierMap = json['supplier'] is Map ? json['supplier'] : null;
    final rawItems = json['items'];
    final itemList = <InboundItem>[];

    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map) {
          itemList.add(InboundItem.fromJson(Map<String, dynamic>.from(it)));
        }
      }
    }
    final totalSkus =
        int.tryParse(
          (json['total_skus'] ?? json['total_sku'])?.toString() ?? '',
        ) ??
        0;

    return InboundManifest(
      code: json['manifest_code']?.toString() ?? json['code']?.toString() ?? '',
      supplierId:
          int.tryParse(
            (json['supplier_id'] ?? supplierMap?['id'] ?? '').toString(),
          ) ??
          0,
      supplierName:
          supplierMap?['name']?.toString() ??
          json['supplier_name']?.toString() ??
          'Supplier Master',
      totalUnits:
          int.tryParse(json['total_units']?.toString() ?? '') ??
          itemList.fold(0, (sum, i) => sum + i.expectedQty),
      status: InboundStatus.fromString(json['status']?.toString()),
      items: itemList,
      totalSkus: totalSkus > 0 ? totalSkus : itemList.length,
    );
  }
}

class InboundStats {
  const InboundStats({
    required this.todayTotal,
    required this.inProgress,
    required this.completed,
    required this.hold,
  });

  final int todayTotal;
  final int inProgress;
  final int completed;
  final int hold;

  factory InboundStats.fromJson(
    Map<String, dynamic> json, {
    required List<InboundManifest> manifests,
  }) {
    int number(Iterable<String> keys, int fallback) {
      for (final key in keys) {
        final value = int.tryParse(json[key]?.toString() ?? '');
        if (value != null) return value;
      }
      return fallback;
    }

    return InboundStats(
      todayTotal: number([
        'total',
        'today_total',
        'today',
        'total_today',
      ], manifests.length),
      inProgress: number(
        ['pending', 'in_progress', 'processing', 'receiving'],
        manifests
            .where(
              (m) =>
                  m.status == InboundStatus.receiving ||
                  m.status == InboundStatus.draft,
            )
            .length,
      ),
      completed: number([
        'completed',
        'closed',
        'finished',
      ], manifests.where((m) => m.status == InboundStatus.closed).length),
      hold: number([
        'hold',
        'on_hold',
      ], manifests.where((m) => m.status == InboundStatus.hold).length),
    );
  }
}

class InboundLocation {
  const InboundLocation({required this.id, required this.rackCode, this.zone});

  final int id;
  final String rackCode;
  final String? zone;

  factory InboundLocation.fromJson(Map<String, dynamic> json) =>
      InboundLocation(
        id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
        rackCode: json['rack_code']?.toString() ?? '',
        zone: json['zone']?.toString(),
      );
}

class InboundManifestDetail {
  const InboundManifestDetail({
    required this.manifest,
    required this.items,
    required this.locations,
  });

  final InboundManifest manifest;
  final List<InboundItem> items;
  final List<InboundLocation> locations;
}
