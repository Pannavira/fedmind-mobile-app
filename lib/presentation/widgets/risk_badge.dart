import 'package:flutter/material.dart';
import '../../core/constants/clinical_constants.dart';

class RiskBadge extends StatelessWidget {
  final String? riskCategory;
  final bool isLarge;
  final bool showIcon;
  final bool useFullClinicalLabel;

  const RiskBadge({
    super.key,
    required this.riskCategory,
    this.isLarge = false,
    this.showIcon = true,
    this.useFullClinicalLabel = false,
  });

  IconData _getRiskIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'low':
        return Icons.check_circle_outline_rounded;
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
    final label = useFullClinicalLabel
        ? ClinicalConstants.getRiskLabel(riskCategory)
        : ClinicalConstants.getRiskShortBadge(riskCategory);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 11 : 8,
        vertical: isLarge ? 5 : 3.5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.40), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              _getRiskIcon(riskCategory),
              size: isLarge ? 14 : 11.5,
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
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: isLarge ? 11.5 : 10,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
