import 'package:flutter/material.dart';
import '../../core/constants/clinical_constants.dart';

class RiskBadge extends StatelessWidget {
  final String? riskCategory;
  final bool isLarge;
  final bool showIcon;

  const RiskBadge({
    super.key,
    required this.riskCategory,
    this.isLarge = false,
    this.showIcon = true,
  });

  IconData _getRiskIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'low':
        return Icons.health_and_safety_outlined;
      case 'borderline':
        return Icons.visibility_outlined;
      case 'moderate':
        return Icons.warning_amber_rounded;
      case 'high':
        return Icons.crisis_alert_rounded;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = ClinicalConstants.getRiskColor(riskCategory);
    final label = (riskCategory ?? 'Unknown').toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 12 : 9,
        vertical: isLarge ? 5 : 3.5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              _getRiskIcon(riskCategory),
              size: isLarge ? 15 : 12,
              color: color,
            ),
            const SizedBox(width: 5),
          ] else ...[
            Container(
              width: isLarge ? 7 : 5,
              height: isLarge ? 7 : 5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: isLarge ? 12 : 10.5,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
