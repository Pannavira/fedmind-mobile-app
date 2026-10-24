import 'package:flutter/material.dart';
import '../../core/constants/clinical_constants.dart';

class RiskBadge extends StatelessWidget {
  final String? riskCategory;
  final bool isLarge;

  const RiskBadge({
    super.key,
    required this.riskCategory,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = ClinicalConstants.getRiskColor(riskCategory);
    final label = (riskCategory ?? 'Unknown').toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 14 : 10,
        vertical: isLarge ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isLarge ? 8 : 6,
            height: isLarge ? 8 : 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: isLarge ? 13 : 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
