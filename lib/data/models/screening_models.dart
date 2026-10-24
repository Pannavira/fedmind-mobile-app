import 'package:json_annotation/json_annotation.dart';

part 'screening_models.g.dart';

// --- 1. Request Schemas ---

@JsonSerializable()
class ScreeningCreateRequest {
  @JsonKey(name: 'participant_id')
  final String participantId;
  final Map<String, dynamic>? metadata;

  ScreeningCreateRequest({required this.participantId, this.metadata});

  factory ScreeningCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$ScreeningCreateRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ScreeningCreateRequestToJson(this);
}

@JsonSerializable()
class ScreeningCreateResponse {
  @JsonKey(name: 'screening_id')
  final String screeningId;
  @JsonKey(name: 'participant_id')
  final String participantId;
  final String status;
  @JsonKey(name: 'created_at')
  final String createdAt;

  ScreeningCreateResponse({
    required this.screeningId,
    required this.participantId,
    required this.status,
    required this.createdAt,
  });

  factory ScreeningCreateResponse.fromJson(Map<String, dynamic> json) =>
      _$ScreeningCreateResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ScreeningCreateResponseToJson(this);
}

@JsonSerializable()
class ScreeningExecuteRequest {
  @JsonKey(name: 'text_features')
  final dynamic textFeatures;
  @JsonKey(name: 'audio_features')
  final dynamic audioFeatures;
  @JsonKey(name: 'visual_features')
  final dynamic visualFeatures;
  final Map<String, dynamic>? metadata;

  ScreeningExecuteRequest({
    required this.textFeatures,
    required this.audioFeatures,
    required this.visualFeatures,
    this.metadata,
  });

  factory ScreeningExecuteRequest.fromJson(Map<String, dynamic> json) =>
      _$ScreeningExecuteRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ScreeningExecuteRequestToJson(this);
}

// --- 2. Result & XAI Sub-Schemas ---

@JsonSerializable()
class PredictionResult {
  @JsonKey(name: 'phq8_score')
  final double phq8Score;
  @JsonKey(name: 'risk_probability_proxy')
  final double riskProbabilityProxy;
  @JsonKey(name: 'binary_prediction')
  final String binaryPrediction;
  @JsonKey(name: 'risk_category')
  final String riskCategory;

  PredictionResult({
    required this.phq8Score,
    required this.riskProbabilityProxy,
    required this.binaryPrediction,
    required this.riskCategory,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) =>
      _$PredictionResultFromJson(json);
  Map<String, dynamic> toJson() => _$PredictionResultToJson(this);
}

@JsonSerializable()
class PatientShapValues {
  final double text;
  final double visual;
  final double audio;

  PatientShapValues({
    required this.text,
    required this.visual,
    required this.audio,
  });

  factory PatientShapValues.fromJson(Map<String, dynamic> json) =>
      _$PatientShapValuesFromJson(json);
  Map<String, dynamic> toJson() => _$PatientShapValuesToJson(this);
}

@JsonSerializable()
class PatientModalityAttribution {
  @JsonKey(name: 'text_pct')
  final double textPct;
  @JsonKey(name: 'visual_pct')
  final double visualPct;
  @JsonKey(name: 'audio_pct')
  final double audioPct;
  @JsonKey(name: 'dominant_modality')
  final String dominantModality;
  @JsonKey(name: 'shap_values')
  final PatientShapValues shapValues;

  PatientModalityAttribution({
    required this.textPct,
    required this.visualPct,
    required this.audioPct,
    required this.dominantModality,
    required this.shapValues,
  });

  factory PatientModalityAttribution.fromJson(Map<String, dynamic> json) =>
      _$PatientModalityAttributionFromJson(json);
  Map<String, dynamic> toJson() => _$PatientModalityAttributionToJson(this);
}

@JsonSerializable()
class GlobalReferenceAttribution {
  final String cohort;
  @JsonKey(name: 'text_pct')
  final double textPct;
  @JsonKey(name: 'visual_pct')
  final double visualPct;
  @JsonKey(name: 'audio_pct')
  final double audioPct;
  @JsonKey(name: 'dominant_modality')
  final String dominantModality;

  GlobalReferenceAttribution({
    required this.cohort,
    required this.textPct,
    required this.visualPct,
    required this.audioPct,
    required this.dominantModality,
  });

  factory GlobalReferenceAttribution.fromJson(Map<String, dynamic> json) =>
      _$GlobalReferenceAttributionFromJson(json);
  Map<String, dynamic> toJson() => _$GlobalReferenceAttributionToJson(this);
}

@JsonSerializable()
class QualityFlags {
  @JsonKey(name: 'low_text_information')
  final bool lowTextInformation;
  @JsonKey(name: 'poor_audio_quality')
  final bool poorAudioQuality;
  @JsonKey(name: 'poor_visual_quality')
  final bool poorVisualQuality;
  final String? details;

  QualityFlags({
    required this.lowTextInformation,
    required this.poorAudioQuality,
    required this.poorVisualQuality,
    this.details,
  });

  factory QualityFlags.fromJson(Map<String, dynamic> json) =>
      _$QualityFlagsFromJson(json);
  Map<String, dynamic> toJson() => _$QualityFlagsToJson(this);
}

@JsonSerializable()
class ModelMetadata {
  @JsonKey(name: 'model_id')
  final String modelId;
  final String name;
  final String version;
  final String architecture;
  final String checkpoint;
  final String checksum;
  @JsonKey(name: 'xai_baseline')
  final String xaiBaseline;
  final String device;

  ModelMetadata({
    required this.modelId,
    required this.name,
    required this.version,
    required this.architecture,
    required this.checkpoint,
    required this.checksum,
    required this.xaiBaseline,
    required this.device,
  });

  factory ModelMetadata.fromJson(Map<String, dynamic> json) =>
      _$ModelMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$ModelMetadataToJson(this);
}

@JsonSerializable()
class XAIMetadata {
  final String method;
  @JsonKey(name: 'num_coalitions')
  final int numCoalitions;
  @JsonKey(name: 'efficiency_axiom_verified')
  final bool efficiencyAxiomVerified;
  @JsonKey(name: 'baseline_expected_value')
  final double baselineExpectedValue;

  XAIMetadata({
    required this.method,
    required this.numCoalitions,
    required this.efficiencyAxiomVerified,
    required this.baselineExpectedValue,
  });

  factory XAIMetadata.fromJson(Map<String, dynamic> json) =>
      _$XAIMetadataFromJson(json);
  Map<String, dynamic> toJson() => _$XAIMetadataToJson(this);
}

// --- 3. Main Response & History Schemas ---

@JsonSerializable()
class ScreeningResponse {
  @JsonKey(name: 'screening_id')
  final String screeningId;
  @JsonKey(name: 'participant_id')
  final String participantId;
  final String status;
  final PredictionResult? prediction;
  @JsonKey(name: 'patient_modality_attribution')
  final PatientModalityAttribution? patientModalityAttribution;
  @JsonKey(name: 'global_reference')
  final GlobalReferenceAttribution? globalReference;
  @JsonKey(name: 'quality_flags')
  final QualityFlags? qualityFlags;
  @JsonKey(name: 'clinical_narrative')
  final String? clinicalNarrative;
  final ModelMetadata? model;
  final XAIMetadata? xai;
  final String? disclaimer;
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @JsonKey(name: 'completed_at')
  final String? completedAt;

  ScreeningResponse({
    required this.screeningId,
    required this.participantId,
    required this.status,
    this.prediction,
    this.patientModalityAttribution,
    this.globalReference,
    this.qualityFlags,
    this.clinicalNarrative,
    this.model,
    this.xai,
    this.disclaimer,
    this.createdAt,
    this.completedAt,
  });

  factory ScreeningResponse.fromJson(Map<String, dynamic> json) =>
      _$ScreeningResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ScreeningResponseToJson(this);
}

@JsonSerializable()
class ScreeningSummaryItem {
  @JsonKey(name: 'screening_id')
  final String screeningId;
  @JsonKey(name: 'participant_id')
  final String participantId;
  final String status;
  @JsonKey(name: 'phq8_score')
  final double? phq8Score;
  @JsonKey(name: 'risk_category')
  final String? riskCategory;
  @JsonKey(name: 'binary_prediction')
  final String? binaryPrediction;
  @JsonKey(name: 'dominant_modality')
  final String? dominantModality;
  @JsonKey(name: 'created_at')
  final String createdAt;
  @JsonKey(name: 'completed_at')
  final String? completedAt;

  ScreeningSummaryItem({
    required this.screeningId,
    required this.participantId,
    required this.status,
    this.phq8Score,
    this.riskCategory,
    this.binaryPrediction,
    this.dominantModality,
    required this.createdAt,
    this.completedAt,
  });

  factory ScreeningSummaryItem.fromJson(Map<String, dynamic> json) =>
      _$ScreeningSummaryItemFromJson(json);
  Map<String, dynamic> toJson() => _$ScreeningSummaryItemToJson(this);
}

@JsonSerializable()
class ScreeningListResponse {
  final int total;
  final List<ScreeningSummaryItem> screenings;

  ScreeningListResponse({required this.total, required this.screenings});

  factory ScreeningListResponse.fromJson(Map<String, dynamic> json) =>
      _$ScreeningListResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ScreeningListResponseToJson(this);
}
