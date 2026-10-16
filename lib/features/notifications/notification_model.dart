import 'package:flutter/material.dart';

enum NotificationType {
  inbound,
  outbound,
  transfer,
  opname,
  system,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String dateText;
  final DateTime timestamp;
  final bool isRead;
  final NotificationType type;
  final String avatarText;
  final Color avatarBg;
  final Color avatarTextColor;
  final String? routeAction;
  final String? actionLabel;
  final Map<String, String>? metadata;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.dateText,
    required this.timestamp,
    required this.isRead,
    required this.type,
    required this.avatarText,
    required this.avatarBg,
    required this.avatarTextColor,
    this.routeAction,
    this.actionLabel,
    this.metadata,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? dateText,
    DateTime? timestamp,
    bool? isRead,
    NotificationType? type,
    String? avatarText,
    Color? avatarBg,
    Color? avatarTextColor,
    String? routeAction,
    String? actionLabel,
    Map<String, String>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      dateText: dateText ?? this.dateText,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      avatarText: avatarText ?? this.avatarText,
      avatarBg: avatarBg ?? this.avatarBg,
      avatarTextColor: avatarTextColor ?? this.avatarTextColor,
      routeAction: routeAction ?? this.routeAction,
      actionLabel: actionLabel ?? this.actionLabel,
      metadata: metadata ?? this.metadata,
    );
  }
}
