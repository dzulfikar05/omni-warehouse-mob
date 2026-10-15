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
