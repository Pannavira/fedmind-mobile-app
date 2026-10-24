// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'screening_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScreeningCreateRequest _$ScreeningCreateRequestFromJson(
  Map<String, dynamic> json,
) => ScreeningCreateRequest(
  participantId: json['participant_id'] as String,
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ScreeningCreateRequestToJson(
  ScreeningCreateRequest instance,
) => <String, dynamic>{
  'participant_id': instance.participantId,
  'metadata': instance.metadata,
};

ScreeningCreateResponse _$ScreeningCreateResponseFromJson(
  Map<String, dynamic> json,
) => ScreeningCreateResponse(
  screeningId: json['screening_id'] as String,
  participantId: json['participant_id'] as String,
  status: json['status'] as String,
  createdAt: json['created_at'] as String,
);

Map<String, dynamic> _$ScreeningCreateResponseToJson(
  ScreeningCreateResponse instance,
) => <String, dynamic>{
  'screening_id': instance.screeningId,
  'participant_id': instance.participantId,
  'status': instance.status,
  'created_at': instance.createdAt,
};

ScreeningExecuteRequest _$ScreeningExecuteRequestFromJson(
  Map<String, dynamic> json,
) => ScreeningExecuteRequest(
  textFeatures: json['text_features'],
  audioFeatures: json['audio_features'],
  visualFeatures: json['visual_features'],
  metadata: json['metadata'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ScreeningExecuteRequestToJson(
  ScreeningExecuteRequest instance,
) => <String, dynamic>{
  'text_features': instance.textFeatures,
  'audio_features': instance.audioFeatures,
  'visual_features': instance.visualFeatures,
  'metadata': instance.metadata,
};

PredictionResult _$PredictionResultFromJson(Map<String, dynamic> json) =>
    PredictionResult(
      phq8Score: (json['phq8_score'] as num).toDouble(),
      riskProbabilityProxy: (json['risk_probability_proxy'] as num).toDouble(),
      binaryPrediction: json['binary_prediction'] as String,
      riskCategory: json['risk_category'] as String,
    );

Map<String, dynamic> _$PredictionResultToJson(PredictionResult instance) =>
    <String, dynamic>{
      'phq8_score': instance.phq8Score,
      'risk_probability_proxy': instance.riskProbabilityProxy,
      'binary_prediction': instance.binaryPrediction,
      'risk_category': instance.riskCategory,
    };

PatientShapValues _$PatientShapValuesFromJson(Map<String, dynamic> json) =>
    PatientShapValues(
      text: (json['text'] as num).toDouble(),
      visual: (json['visual'] as num).toDouble(),
      audio: (json['audio'] as num).toDouble(),
    );

Map<String, dynamic> _$PatientShapValuesToJson(PatientShapValues instance) =>
    <String, dynamic>{
      'text': instance.text,
      'visual': instance.visual,
      'audio': instance.audio,
    };

PatientModalityAttribution _$PatientModalityAttributionFromJson(
  Map<String, dynamic> json,
) => PatientModalityAttribution(
  textPct: (json['text_pct'] as num).toDouble(),
  visualPct: (json['visual_pct'] as num).toDouble(),
  audioPct: (json['audio_pct'] as num).toDouble(),
  dominantModality: json['dominant_modality'] as String,
  shapValues: PatientShapValues.fromJson(
    json['shap_values'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$PatientModalityAttributionToJson(
  PatientModalityAttribution instance,
) => <String, dynamic>{
  'text_pct': instance.textPct,
  'visual_pct': instance.visualPct,
  'audio_pct': instance.audioPct,
  'dominant_modality': instance.dominantModality,
  'shap_values': instance.shapValues,
};

GlobalReferenceAttribution _$GlobalReferenceAttributionFromJson(
  Map<String, dynamic> json,
) => GlobalReferenceAttribution(
  cohort: json['cohort'] as String,
  textPct: (json['text_pct'] as num).toDouble(),
  visualPct: (json['visual_pct'] as num).toDouble(),
  audioPct: (json['audio_pct'] as num).toDouble(),
  dominantModality: json['dominant_modality'] as String,
);

Map<String, dynamic> _$GlobalReferenceAttributionToJson(
  GlobalReferenceAttribution instance,
) => <String, dynamic>{
  'cohort': instance.cohort,
  'text_pct': instance.textPct,
  'visual_pct': instance.visualPct,
  'audio_pct': instance.audioPct,
  'dominant_modality': instance.dominantModality,
};

QualityFlags _$QualityFlagsFromJson(Map<String, dynamic> json) => QualityFlags(
  lowTextInformation: json['low_text_information'] as bool,
  poorAudioQuality: json['poor_audio_quality'] as bool,
  poorVisualQuality: json['poor_visual_quality'] as bool,
  details: json['details'] as String?,
);

Map<String, dynamic> _$QualityFlagsToJson(QualityFlags instance) =>
    <String, dynamic>{
      'low_text_information': instance.lowTextInformation,
      'poor_audio_quality': instance.poorAudioQuality,
      'poor_visual_quality': instance.poorVisualQuality,
      'details': instance.details,
    };

ModelMetadata _$ModelMetadataFromJson(Map<String, dynamic> json) =>
    ModelMetadata(
      modelId: json['model_id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      architecture: json['architecture'] as String,
      checkpoint: json['checkpoint'] as String,
      checksum: json['checksum'] as String,
      xaiBaseline: json['xai_baseline'] as String,
      device: json['device'] as String,
    );

Map<String, dynamic> _$ModelMetadataToJson(ModelMetadata instance) =>
    <String, dynamic>{
      'model_id': instance.modelId,
      'name': instance.name,
      'version': instance.version,
      'architecture': instance.architecture,
      'checkpoint': instance.checkpoint,
      'checksum': instance.checksum,
      'xai_baseline': instance.xaiBaseline,
      'device': instance.device,
    };

XAIMetadata _$XAIMetadataFromJson(Map<String, dynamic> json) => XAIMetadata(
  method: json['method'] as String,
  numCoalitions: (json['num_coalitions'] as num).toInt(),
  efficiencyAxiomVerified: json['efficiency_axiom_verified'] as bool,
  baselineExpectedValue: (json['baseline_expected_value'] as num).toDouble(),
);

Map<String, dynamic> _$XAIMetadataToJson(XAIMetadata instance) =>
    <String, dynamic>{
      'method': instance.method,
      'num_coalitions': instance.numCoalitions,
      'efficiency_axiom_verified': instance.efficiencyAxiomVerified,
      'baseline_expected_value': instance.baselineExpectedValue,
    };

ScreeningResponse _$ScreeningResponseFromJson(
  Map<String, dynamic> json,
) => ScreeningResponse(
  screeningId: json['screening_id'] as String,
  participantId: json['participant_id'] as String,
  status: json['status'] as String,
  prediction: json['prediction'] == null
      ? null
      : PredictionResult.fromJson(json['prediction'] as Map<String, dynamic>),
  patientModalityAttribution: json['patient_modality_attribution'] == null
      ? null
      : PatientModalityAttribution.fromJson(
          json['patient_modality_attribution'] as Map<String, dynamic>,
        ),
  globalReference: json['global_reference'] == null
      ? null
      : GlobalReferenceAttribution.fromJson(
          json['global_reference'] as Map<String, dynamic>,
        ),
  qualityFlags: json['quality_flags'] == null
      ? null
      : QualityFlags.fromJson(json['quality_flags'] as Map<String, dynamic>),
  clinicalNarrative: json['clinical_narrative'] as String?,
  model: json['model'] == null
      ? null
      : ModelMetadata.fromJson(json['model'] as Map<String, dynamic>),
  xai: json['xai'] == null
      ? null
      : XAIMetadata.fromJson(json['xai'] as Map<String, dynamic>),
  disclaimer: json['disclaimer'] as String?,
  createdAt: json['created_at'] as String?,
  completedAt: json['completed_at'] as String?,
);

Map<String, dynamic> _$ScreeningResponseToJson(ScreeningResponse instance) =>
    <String, dynamic>{
      'screening_id': instance.screeningId,
      'participant_id': instance.participantId,
      'status': instance.status,
      'prediction': instance.prediction,
      'patient_modality_attribution': instance.patientModalityAttribution,
      'global_reference': instance.globalReference,
      'quality_flags': instance.qualityFlags,
      'clinical_narrative': instance.clinicalNarrative,
      'model': instance.model,
      'xai': instance.xai,
      'disclaimer': instance.disclaimer,
      'created_at': instance.createdAt,
      'completed_at': instance.completedAt,
    };

ScreeningSummaryItem _$ScreeningSummaryItemFromJson(
  Map<String, dynamic> json,
) => ScreeningSummaryItem(
  screeningId: json['screening_id'] as String,
  participantId: json['participant_id'] as String,
  status: json['status'] as String,
  phq8Score: (json['phq8_score'] as num?)?.toDouble(),
  riskCategory: json['risk_category'] as String?,
  binaryPrediction: json['binary_prediction'] as String?,
  dominantModality: json['dominant_modality'] as String?,
  createdAt: json['created_at'] as String,
  completedAt: json['completed_at'] as String?,
);

Map<String, dynamic> _$ScreeningSummaryItemToJson(
  ScreeningSummaryItem instance,
) => <String, dynamic>{
  'screening_id': instance.screeningId,
  'participant_id': instance.participantId,
  'status': instance.status,
  'phq8_score': instance.phq8Score,
  'risk_category': instance.riskCategory,
  'binary_prediction': instance.binaryPrediction,
  'dominant_modality': instance.dominantModality,
  'created_at': instance.createdAt,
  'completed_at': instance.completedAt,
};

ScreeningListResponse _$ScreeningListResponseFromJson(
  Map<String, dynamic> json,
) => ScreeningListResponse(
  total: (json['total'] as num).toInt(),
  screenings: (json['screenings'] as List<dynamic>)
      .map((e) => ScreeningSummaryItem.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ScreeningListResponseToJson(
  ScreeningListResponse instance,
) => <String, dynamic>{
  'total': instance.total,
  'screenings': instance.screenings,
};
