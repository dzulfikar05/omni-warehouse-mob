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
        return 'HOLD';
    }
  }

  static InboundStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'RECEIVING':
        return InboundStatus.receiving;
      case 'CLOSED':
      case 'COMPLETED':
        return InboundStatus.closed;
      case 'HOLD':
        return InboundStatus.hold;
      case 'DRAFT':
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

  Color get border {
    switch (this) {
      case InboundStatus.receiving:
        return AppColors.warningBorder;
      case InboundStatus.draft:
        return AppColors.primaryBorder;
      case InboundStatus.closed:
        return AppColors.successBorder;
      case InboundStatus.hold:
        return AppColors.dangerBorder;
    }
  }
}

class InboundItem {
  InboundItem({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.expectedQty,
    this.goodQty = 0,
    this.damagedQty = 0,
    this.targetRack,
    this.unit = 'Koli',
    this.category = 'Logistik',
    this.notes,
  });

  final String id;
  final String sku;
  final String barcode;
  final String name;
  final int expectedQty;
  int goodQty;
  int damagedQty;
  String? targetRack;
  final String unit;
  final String category;
  String? notes;

  int get totalScanned => goodQty + damagedQty;
  bool get isCompleted => totalScanned >= expectedQty;
  int get remaining => (expectedQty - totalScanned).clamp(0, expectedQty);

  InboundItem copyWith({
    String? id,
    String? sku,
    String? barcode,
    String? name,
    int? expectedQty,
    int? goodQty,
    int? damagedQty,
    String? targetRack,
    String? unit,
    String? category,
    String? notes,
  }) {
    return InboundItem(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      expectedQty: expectedQty ?? this.expectedQty,
      goodQty: goodQty ?? this.goodQty,
      damagedQty: damagedQty ?? this.damagedQty,
      targetRack: targetRack ?? this.targetRack,
      unit: unit ?? this.unit,
      category: category ?? this.category,
      notes: notes ?? this.notes,
    );
  }

  factory InboundItem.fromJson(Map<String, dynamic> json) {
    return InboundItem(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      expectedQty: (json['expected_qty'] ?? json['expectedQty'] ?? 0) as int,
      goodQty: (json['good_qty'] ?? json['goodQty'] ?? 0) as int,
      damagedQty: (json['damaged_qty'] ?? json['damagedQty'] ?? 0) as int,
      targetRack: json['target_rack']?.toString() ?? json['targetRack']?.toString(),
      unit: json['unit']?.toString() ?? 'Koli',
      category: json['category']?.toString() ?? 'Logistik',
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sku': sku,
    'barcode': barcode,
    'name': name,
    'expected_qty': expectedQty,
    'good_qty': goodQty,
    'damaged_qty': damagedQty,
    'target_rack': targetRack,
    'unit': unit,
    'category': category,
    'notes': notes,
  };
}

class InboundManifest {
  InboundManifest({
    required this.code,
    required this.supplier,
    required this.warehouse,
    required this.dockBay,
    required this.totalUnits,
    required this.status,
    required this.items,
    this.startedAt,
    this.completedAt,
    this.truckPlate,
    this.driverName,
    this.isAdhoc = false,
  });

  final String code;
  final String supplier;
  final String warehouse;
  final String dockBay;
  final int totalUnits;
  InboundStatus status;
  final List<InboundItem> items;
  final String? startedAt;
  final String? completedAt;
  final String? truckPlate;
  final String? driverName;
  final bool isAdhoc;

  factory InboundManifest.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemList = <InboundItem>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          itemList.add(InboundItem.fromJson(it));
        } else if (it is Map) {
          itemList.add(InboundItem.fromJson(Map<String, dynamic>.from(it)));
        }
      }
    }

    return InboundManifest(
      code: json['code']?.toString() ?? '',
      supplier: json['supplier']?.toString() ?? '',
      warehouse: json['warehouse']?.toString() ?? '',
      dockBay: json['dock_bay']?.toString() ?? json['dockBay']?.toString() ?? 'Dock Bay 01',
      totalUnits: (json['total_units'] ?? json['totalUnits'] ?? 0) as int,
      status: InboundStatus.fromString(json['status']?.toString()),
      items: itemList,
      startedAt: json['started_at']?.toString() ?? json['startedAt']?.toString(),
      completedAt: json['completed_at']?.toString() ?? json['completedAt']?.toString(),
      truckPlate: json['truck_plate']?.toString() ?? json['truckPlate']?.toString(),
      driverName: json['driver_name']?.toString() ?? json['driverName']?.toString(),
      isAdhoc: (json['is_adhoc'] ?? json['isAdhoc'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'supplier': supplier,
    'warehouse': warehouse,
    'dock_bay': dockBay,
    'total_units': totalUnits,
    'status': status.label,
    'items': items.map((e) => e.toJson()).toList(),
    'started_at': startedAt,
    'completed_at': completedAt,
    'truck_plate': truckPlate,
    'driver_name': driverName,
    'is_adhoc': isAdhoc,
  };

  int get scannedUnits =>
      items.fold(0, (sum, item) => sum + item.totalScanned);

  int get goodUnits =>
      items.fold(0, (sum, item) => sum + item.goodQty);

  int get damagedUnits =>
      items.fold(0, (sum, item) => sum + item.damagedQty);

  double get progressPercentage {
    if (totalUnits == 0) return 0.0;
    return (scannedUnits / totalUnits).clamp(0.0, 1.0);
  }

  bool get isFullyCompleted => scannedUnits >= totalUnits;
}

class PutawayRequest {
  final String manifestCode;
  final String itemId;
  final int goodQty;
  final int damagedQty;
  final String? targetRack;
  final String? notes;

  const PutawayRequest({
    required this.manifestCode,
    required this.itemId,
    required this.goodQty,
    required this.damagedQty,
    this.targetRack,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'manifest_code': manifestCode,
    'item_id': itemId,
    'good_qty': goodQty,
    'damaged_qty': damagedQty,
    'target_rack': targetRack,
    'notes': notes,
  };
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
}
