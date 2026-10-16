import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum TransferType {
  binToBin,      // Internal pindah rak (Synchronous / Instan)
  interWarehouse, // Kirim antar gudang/cabang (In-Transit)
  replenishment; // UMKM: Gudang simpan ke display etalase depan

  String get label {
    switch (this) {
      case TransferType.binToBin:
        return 'PINDAH RAK';
      case TransferType.interWarehouse:
        return 'ANTAR GUDANG';
      case TransferType.replenishment:
        return 'DISPLAY TOKO';
    }
  }

  Color get color {
    switch (this) {
      case TransferType.binToBin:
        return AppColors.primary;
      case TransferType.interWarehouse:
        return const Color(0xFF0284C7);
      case TransferType.replenishment:
        return const Color(0xFF7C3AED);
    }
  }

  Color get bg {
    switch (this) {
      case TransferType.binToBin:
        return AppColors.primaryLight;
      case TransferType.interWarehouse:
        return const Color(0xFFF0F9FF);
      case TransferType.replenishment:
        return const Color(0xFFF5F3FF);
    }
  }

  Color get border {
    switch (this) {
      case TransferType.binToBin:
        return AppColors.primaryBorder;
      case TransferType.interWarehouse:
        return const Color(0xFFBAE6FD);
      case TransferType.replenishment:
        return const Color(0xFFDDD6FE);
    }
  }
}

enum TransferStatus {
  completed,
  inTransit,
  draft;

  String get label {
    switch (this) {
      case TransferStatus.completed:
        return 'SELESAI';
      case TransferStatus.inTransit:
        return 'DALAM PERJALANAN';
      case TransferStatus.draft:
        return 'DRAFT';
    }
  }

  Color get color {
    switch (this) {
      case TransferStatus.completed:
        return AppColors.success;
      case TransferStatus.inTransit:
        return const Color(0xFFD97706);
      case TransferStatus.draft:
        return AppColors.textSecondary;
    }
  }

  Color get bg {
    switch (this) {
      case TransferStatus.completed:
        return AppColors.successLight;
      case TransferStatus.inTransit:
        return AppColors.warningLight;
      case TransferStatus.draft:
        return const Color(0xFFF1F5F9);
    }
  }

  Color get border {
    switch (this) {
      case TransferStatus.completed:
        return AppColors.successBorder;
      case TransferStatus.inTransit:
        return AppColors.warningBorder;
      case TransferStatus.draft:
        return AppColors.border;
    }
  }
}

class StockTransferItem {
  StockTransferItem({
    required this.id,
    required this.referenceNumber,
    required this.type,
    required this.sku,
    required this.barcode,
    required this.productName,
    required this.fromLocation,
    required this.toLocation,
    required this.quantity,
    required this.unit,
    required this.status,
    required this.createdAt,
    this.operatorName = 'Budi Santoso',
    this.notes,
    this.availableStock = 100,
  });

  final String id;
  final String referenceNumber;
  final TransferType type;
  final String sku;
  final String barcode;
  final String productName;
  final String fromLocation;
  final String toLocation;
  final int quantity;
  final String unit;
  TransferStatus status;
  final String createdAt;
  final String operatorName;
  final String? notes;
  final int availableStock;

  StockTransferItem copyWith({
    String? id,
    String? referenceNumber,
    TransferType? type,
    String? sku,
    String? barcode,
    String? productName,
    String? fromLocation,
    String? toLocation,
    int? quantity,
    String? unit,
    TransferStatus? status,
    String? createdAt,
    String? operatorName,
    String? notes,
    int? availableStock,
  }) {
    return StockTransferItem(
      id: id ?? this.id,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      type: type ?? this.type,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      operatorName: operatorName ?? this.operatorName,
      notes: notes ?? this.notes,
      availableStock: availableStock ?? this.availableStock,
    );
  }
}

class TransferStats {
  const TransferStats({
    required this.todayTotal,
    required this.completed,
    required this.inTransit,
  });

  final int todayTotal;
  final int completed;
  final int inTransit;
}
