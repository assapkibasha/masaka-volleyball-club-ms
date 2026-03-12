import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

enum PaymentStatus {
  paid,
  unpaid,
  partial,
  active,
  inactive
}

class StatusBadge extends StatelessWidget {
  final PaymentStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color getBackgroundColor() {
      switch (status) {
        case PaymentStatus.paid:
          return AppColors.statusPaid.withValues(alpha: 0.1);
        case PaymentStatus.unpaid:
          return AppColors.statusUnpaid.withValues(alpha: 0.1);
        case PaymentStatus.partial:
          return AppColors.statusPartial.withValues(alpha: 0.1);
        case PaymentStatus.active:
          return AppColors.statusActive.withValues(alpha: 0.1);
        case PaymentStatus.inactive:
          return AppColors.statusInactive.withValues(alpha: 0.1);
      }
    }

    Color getTextColor() {
      switch (status) {
        case PaymentStatus.paid:
          return AppColors.statusPaid;
        case PaymentStatus.unpaid:
          return AppColors.statusUnpaid;
        case PaymentStatus.partial:
          return AppColors.statusPartial;
        case PaymentStatus.active:
          return AppColors.statusActive;
        case PaymentStatus.inactive:
          return AppColors.statusInactive;
      }
    }

    String getText() {
      switch (status) {
        case PaymentStatus.paid:
          return 'Paid';
        case PaymentStatus.unpaid:
          return 'Unpaid';
        case PaymentStatus.partial:
          return 'Partial';
        case PaymentStatus.active:
          return 'Active';
        case PaymentStatus.inactive:
          return 'Inactive';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: getBackgroundColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: getTextColor().withValues(alpha: 0.2)),
      ),
      child: Text(
        getText(),
        style: TextStyle(
          color: getTextColor(),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
