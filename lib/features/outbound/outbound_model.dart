import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum OutboundStatus {
  readyToPick,
  picking,
  packing,
  dispatched,
  hold;

  String get label {
    switch (this) {
      case OutboundStatus.readyToPick:
        return 'SIAP PICKING';
      case OutboundStatus.picking:
        return 'PICKING';
      case OutboundStatus.packing:
        return 'PACKING';
      case OutboundStatus.dispatched:
        return 'DISPATCHED';
      case OutboundStatus.hold:
        return 'HOLD';
    }
  }

  Color get color {
    switch (this) {
      case OutboundStatus.readyToPick:
        return AppColors.primary;
      case OutboundStatus.picking:
        return const Color(0xFFD97706); // Amber
      case OutboundStatus.packing:
        return const Color(0xFF7C3AED); // Purple
      case OutboundStatus.dispatched:
        return AppColors.success;
      case OutboundStatus.hold:
        return AppColors.danger;
    }
  }

  Color get bg {
    switch (this) {
      case OutboundStatus.readyToPick:
        return AppColors.primaryLight;
      case OutboundStatus.picking:
        return AppColors.warningLight;
      case OutboundStatus.packing:
        return const Color(0xFFF5F3FF);
      case OutboundStatus.dispatched:
        return AppColors.successLight;
      case OutboundStatus.hold:
        return AppColors.dangerLight;
    }
  }

  Color get border {
    switch (this) {
      case OutboundStatus.readyToPick:
        return AppColors.primaryBorder;
      case OutboundStatus.picking:
        return AppColors.warningBorder;
      case OutboundStatus.packing:
        return const Color(0xFFDDD6FE);
      case OutboundStatus.dispatched:
        return AppColors.successBorder;
      case OutboundStatus.hold:
        return AppColors.dangerBorder;
    }
  }
}

class OutboundItem {
  OutboundItem({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.fromRack,
    required this.orderQty,
    this.pickedQty = 0,
    this.packedQty = 0,
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
  int pickedQty;
  int packedQty;
  final String unit;
  final String category;
  String? notes;

  bool get isFullyPicked => pickedQty >= orderQty;
  bool get isFullyPacked => packedQty >= orderQty;
  int get remainingToPick => (orderQty - pickedQty).clamp(0, orderQty);

  OutboundItem copyWith({
    String? id,
    String? sku,
    String? barcode,
    String? name,
    String? fromRack,
    int? orderQty,
    int? pickedQty,
    int? packedQty,
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
      pickedQty: pickedQty ?? this.pickedQty,
      packedQty: packedQty ?? this.packedQty,
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
    this.waveId,
    this.startedAt,
    this.dispatchedAt,
    this.trackingNumber,
    this.isAdhocExpress = false,
  });

  final String code;
  final String customer;
  final String destination;
  final String expedition;
  final String stagingBay;
  OutboundStatus status;
  final List<OutboundItem> items;
  final String? waveId;
  final String? startedAt;
  final String? dispatchedAt;
  final String? trackingNumber;
  final bool isAdhocExpress;

  int get totalOrderUnits =>
      items.fold(0, (sum, it) => sum + it.orderQty);

  int get totalPickedUnits =>
      items.fold(0, (sum, it) => sum + it.pickedQty);

  int get totalPackedUnits =>
      items.fold(0, (sum, it) => sum + it.packedQty);

  double get progressPercentage {
    if (totalOrderUnits == 0) return 0.0;
    return (totalPickedUnits / totalOrderUnits).clamp(0.0, 1.0);
  }

  bool get isFullyPicked => totalPickedUnits >= totalOrderUnits;
  bool get isFullyDispatched => status == OutboundStatus.dispatched;
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
}
