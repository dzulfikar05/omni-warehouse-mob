import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum OpnameSessionStatus {
  active,
  reconciling,
  completed;

  String get label {
    switch (this) {
      case OpnameSessionStatus.active:
        return 'AKTIF MENGHITUNG';
      case OpnameSessionStatus.reconciling:
        return 'REKONSILIASI WEB';
      case OpnameSessionStatus.completed:
        return 'SELESAI';
    }
  }

  Color get color {
    switch (this) {
      case OpnameSessionStatus.active:
        return AppColors.primary;
      case OpnameSessionStatus.reconciling:
        return AppColors.warning;
      case OpnameSessionStatus.completed:
        return AppColors.success;
    }
  }

  Color get bg {
    switch (this) {
      case OpnameSessionStatus.active:
        return AppColors.primaryLight;
      case OpnameSessionStatus.reconciling:
        return AppColors.warningLight;
      case OpnameSessionStatus.completed:
        return AppColors.successLight;
    }
  }

  Color get border {
    switch (this) {
      case OpnameSessionStatus.active:
        return AppColors.primaryBorder;
      case OpnameSessionStatus.reconciling:
        return AppColors.warningBorder;
      case OpnameSessionStatus.completed:
        return AppColors.successBorder;
    }
  }
}

enum ItemOpnameStatus {
  pending,
  match,
  deficit,
  surplus;

  String get label {
    switch (this) {
      case ItemOpnameStatus.pending:
        return 'BELUM DIHITUNG';
      case ItemOpnameStatus.match:
        return 'COCOK';
      case ItemOpnameStatus.deficit:
        return 'DEFISIT';
      case ItemOpnameStatus.surplus:
        return 'SURPLUS';
    }
  }

  Color get color {
    switch (this) {
      case ItemOpnameStatus.pending:
        return AppColors.textMuted;
      case ItemOpnameStatus.match:
        return AppColors.success;
      case ItemOpnameStatus.deficit:
        return AppColors.danger;
      case ItemOpnameStatus.surplus:
        return AppColors.warning;
    }
  }

  Color get bg {
    switch (this) {
      case ItemOpnameStatus.pending:
        return const Color(0xFFF1F5F9);
      case ItemOpnameStatus.match:
        return AppColors.successLight;
      case ItemOpnameStatus.deficit:
        return AppColors.dangerLight;
      case ItemOpnameStatus.surplus:
        return AppColors.warningLight;
    }
  }

  Color get border {
    switch (this) {
      case ItemOpnameStatus.pending:
        return AppColors.border;
      case ItemOpnameStatus.match:
        return AppColors.successBorder;
      case ItemOpnameStatus.deficit:
        return AppColors.dangerBorder;
      case ItemOpnameStatus.surplus:
        return AppColors.warningBorder;
    }
  }
}

class OpnameItem {
  OpnameItem({
    required this.id,
    required this.sku,
    required this.barcode,
    required this.name,
    required this.category,
    required this.rack,
    required this.systemQty,
    this.physicalQty,
    required this.unit,
    this.batch = 'BATCH-2026-A',
    this.notes,
    this.scannedAt,
  });

  final String id;
  final String sku;
  final String barcode;
  final String name;
  final String category;
  final String rack;
  final int systemQty;
  final int? physicalQty;
  final String unit;
  final String batch;
  final String? notes;
  final String? scannedAt;

  int? get variance => physicalQty == null ? null : (physicalQty! - systemQty);

  ItemOpnameStatus get status {
    if (physicalQty == null) return ItemOpnameStatus.pending;
    final diff = physicalQty! - systemQty;
    if (diff == 0) return ItemOpnameStatus.match;
    if (diff < 0) return ItemOpnameStatus.deficit;
    return ItemOpnameStatus.surplus;
  }

  OpnameItem copyWith({
    String? id,
    String? sku,
    String? barcode,
    String? name,
    String? category,
    String? rack,
    int? systemQty,
    int? physicalQty,
    String? unit,
    String? batch,
    String? notes,
    String? scannedAt,
  }) {
    return OpnameItem(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      category: category ?? this.category,
      rack: rack ?? this.rack,
      systemQty: systemQty ?? this.systemQty,
      physicalQty: physicalQty ?? this.physicalQty,
      unit: unit ?? this.unit,
      batch: batch ?? this.batch,
      notes: notes ?? this.notes,
      scannedAt: scannedAt ?? this.scannedAt,
    );
  }
}

class OpnameSession {
  OpnameSession({
    required this.sessionCode,
    required this.title,
    required this.warehouseName,
    required this.zone,
    required this.status,
    required this.assignedOperator,
    required this.createdAt,
    required this.items,
    this.isBlindCount = true,
    this.isAdhoc = false,
  });

  final String sessionCode;
  final String title;
  final String warehouseName;
  final String zone;
  OpnameSessionStatus status;
  final String assignedOperator;
  final String createdAt;
  final List<OpnameItem> items;
  final bool isBlindCount;
  final bool isAdhoc;

  int get totalItems => items.length;
  int get countedItems => items.where((i) => i.physicalQty != null).length;
  double get progress => totalItems == 0 ? 0.0 : countedItems / totalItems;
  int get matchCount => items.where((i) => i.status == ItemOpnameStatus.match).length;
  int get discrepancyCount =>
      items.where((i) => i.status == ItemOpnameStatus.deficit || i.status == ItemOpnameStatus.surplus).length;

  OpnameSession copyWith({
    String? sessionCode,
    String? title,
    String? warehouseName,
    String? zone,
    OpnameSessionStatus? status,
    String? assignedOperator,
    String? createdAt,
    List<OpnameItem>? items,
    bool? isBlindCount,
    bool? isAdhoc,
  }) {
    return OpnameSession(
      sessionCode: sessionCode ?? this.sessionCode,
      title: title ?? this.title,
      warehouseName: warehouseName ?? this.warehouseName,
      zone: zone ?? this.zone,
      status: status ?? this.status,
      assignedOperator: assignedOperator ?? this.assignedOperator,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      isBlindCount: isBlindCount ?? this.isBlindCount,
      isAdhoc: isAdhoc ?? this.isAdhoc,
    );
  }
}

class OpnameStats {
  const OpnameStats({
    required this.activeSessions,
    required this.totalItemsCounted,
    required this.discrepancyCount,
  });

  final int activeSessions;
  final int totalItemsCounted;
  final int discrepancyCount;
}
