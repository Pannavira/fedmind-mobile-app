import 'package:flutter/material.dart';

class ClinicalConstants {
  // PHQ-8 Thresholds according to Fed-Mind research protocol
  static const double scoreLowMax = 7.99;
  static const double scoreBorderlineMin = 8.0;
  static const double scoreBorderlineMax = 9.99;
  static const double scoreModerateMin = 10.0;
  static const double scoreModerateMax = 14.99;
  static const double scoreHighMin = 15.0;
  static const double scoreMax = 24.0;

  // Clinical risk colors
  static const Color riskLowColor = Color(0xFF10B981); // Emerald Green
  static const Color riskBorderlineColor = Color(0xFFF59E0B); // Amber
  static const Color riskModerateColor = Color(0xFFF97316); // Orange
  static const Color riskHighColor = Color(0xFFEF4444); // Crimson Red

  // Modality colors for XAI Charts
  static const Color textModalityColor = Color(0xFF3B82F6); // Blue
  static const Color visualModalityColor = Color(0xFF8B5CF6); // Purple
  static const Color audioModalityColor = Color(0xFFEC4899); // Pink

  static Color getRiskColor(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return riskLowColor;
      case 'borderline':
        return riskBorderlineColor;
      case 'moderate':
        return riskModerateColor;
      case 'high':
        return riskHighColor;
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  static String getRiskLabel(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Low Risk (Non-Depression)';
      case 'borderline':
        return 'Borderline (Clinical Monitoring)';
      case 'moderate':
        return 'Moderate (Depression Indicated)';
      case 'high':
        return 'High (Severe Depression)';
      default:
        return 'Undefined';
    }
  }

  static String getRiskDescription(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Score is below the clinical threshold of 8.0. No significant depressive symptoms indicated.';
      case 'borderline':
        return 'Score falls in the range of 8.0 – 9.9. Borderline zone warranting regular clinical observation.';
      case 'moderate':
        return 'Score falls in the range of 10.0 – 14.9. Clinically significant depressive symptoms requiring further assessment.';
      case 'high':
        return 'Score is >= 15.0. Severe depression indicated; prompt psychiatric evaluation is recommended.';
      default:
        return '-';
    }
  }

  /// Therapeutic intervention guidance for psychologists / clinical counselors
  static String getCounselingGuidance(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Facilitate promotive mental health psychoeducation, explore adaptive coping strategies, and maintain wellness routines.';
      case 'borderline':
        return 'Explore subclinical stressors (occupational, interpersonal, sleep patterns). Maintain active observation and schedule follow-up review in 2–4 weeks.';
      case 'moderate':
        return 'Initiate structured psychotherapy protocol (CBT / ACT). Assess cognitive distortions, anhedonia, and functional daily life impairments.';
      case 'high':
        return 'Prioritize affective stabilization and crisis/safety evaluation (suicide/self-harm risk). Promptly coordinate psychiatric referral for comprehensive care.';
      default:
        return 'Perform holistic clinical observation tailored to patient history.';
    }
  }

  /// Concise action title for clinical counseling recommendation
  static String getCounselingActionTitle(String? riskCategory) {
    switch (riskCategory?.toLowerCase()) {
      case 'low':
        return 'Promotive Counseling & Resilience Building';
      case 'borderline':
        return 'Clinical Observation & Periodic Review';
      case 'moderate':
        return 'Structured Psychotherapy (CBT/ACT)';
      case 'high':
        return 'High Priority / Psychiatric Collaboration';
      default:
        return 'General Clinical Observation';
    }
  }
}
