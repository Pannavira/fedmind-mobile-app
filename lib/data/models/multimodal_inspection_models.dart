class VisualFrameInspection {
  final int frameIndex;
  final double timeSec;
  final bool faceFound;
  final double confidence;
  final double bboxLeft;
  final double bboxTop;
  final double bboxRight;
  final double bboxBottom;
  final double eulerX; // Pitch (menunduk/mendongak)
  final double eulerY; // Yaw (menoleh kiri/kanan)
  final double eulerZ; // Roll (miring)
  final double browTension; // AU04
  final double eyeOpenness; // AU05 / AU45
  final double smileIntensity; // AU12
  final double lipDepressor; // AU15
  final double motionEnergy;
  final String expressionLabel;

  const VisualFrameInspection({
    required this.frameIndex,
    required this.timeSec,
    required this.faceFound,
    required this.confidence,
    required this.bboxLeft,
    required this.bboxTop,
    required this.bboxRight,
    required this.bboxBottom,
    required this.eulerX,
    required this.eulerY,
    required this.eulerZ,
    required this.browTension,
    required this.eyeOpenness,
    required this.smileIntensity,
    required this.lipDepressor,
    required this.motionEnergy,
    required this.expressionLabel,
  });

  Map<String, dynamic> toJson() => {
    'frameIndex': frameIndex,
    'timeSec': timeSec,
    'faceFound': faceFound,
    'confidence': confidence,
    'bboxLeft': bboxLeft,
    'bboxTop': bboxTop,
    'bboxRight': bboxRight,
    'bboxBottom': bboxBottom,
    'eulerX': eulerX,
    'eulerY': eulerY,
    'eulerZ': eulerZ,
    'browTension': browTension,
    'eyeOpenness': eyeOpenness,
    'smileIntensity': smileIntensity,
    'lipDepressor': lipDepressor,
    'motionEnergy': motionEnergy,
    'expressionLabel': expressionLabel,
  };

  factory VisualFrameInspection.fromJson(Map<String, dynamic> json) => VisualFrameInspection(
    frameIndex: json['frameIndex'] as int? ?? 0,
    timeSec: (json['timeSec'] as num?)?.toDouble() ?? 0.0,
    faceFound: json['faceFound'] as bool? ?? false,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    bboxLeft: (json['bboxLeft'] as num?)?.toDouble() ?? 0.0,
    bboxTop: (json['bboxTop'] as num?)?.toDouble() ?? 0.0,
    bboxRight: (json['bboxRight'] as num?)?.toDouble() ?? 0.0,
    bboxBottom: (json['bboxBottom'] as num?)?.toDouble() ?? 0.0,
    eulerX: (json['eulerX'] as num?)?.toDouble() ?? 0.0,
    eulerY: (json['eulerY'] as num?)?.toDouble() ?? 0.0,
    eulerZ: (json['eulerZ'] as num?)?.toDouble() ?? 0.0,
    browTension: (json['browTension'] as num?)?.toDouble() ?? 0.0,
    eyeOpenness: (json['eyeOpenness'] as num?)?.toDouble() ?? 0.0,
    smileIntensity: (json['smileIntensity'] as num?)?.toDouble() ?? 0.0,
    lipDepressor: (json['lipDepressor'] as num?)?.toDouble() ?? 0.0,
    motionEnergy: (json['motionEnergy'] as num?)?.toDouble() ?? 0.0,
    expressionLabel: json['expressionLabel'] as String? ?? 'Neutral',
  );
}

class TranscriptSegmentItem {
  final String timeRangeLabel;
  final String text;
  final String translatedText;
  final List<String> detectedKeywords;
  final String prosodyNote;

  const TranscriptSegmentItem({
    required this.timeRangeLabel,
    required this.text,
    this.translatedText = '',
    this.detectedKeywords = const [],
    this.prosodyNote = '',
  });

  Map<String, dynamic> toJson() => {
    'timeRangeLabel': timeRangeLabel,
    'text': text,
    'translatedText': translatedText,
    'detectedKeywords': detectedKeywords,
    'prosodyNote': prosodyNote,
  };

  factory TranscriptSegmentItem.fromJson(Map<String, dynamic> json) => TranscriptSegmentItem(
    timeRangeLabel: json['timeRangeLabel'] as String? ?? '',
    text: json['text'] as String? ?? '',
    translatedText: json['translatedText'] as String? ?? '',
    detectedKeywords: (json['detectedKeywords'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    prosodyNote: json['prosodyNote'] as String? ?? '',
  );
}

class CoalitionStepScore {
  final String coalitionCode;
  final String label;
  final String description;
  final bool hasAudio;
  final bool hasVisual;
  final bool hasText;
  final double predictedScore;

  const CoalitionStepScore({
    required this.coalitionCode,
    required this.label,
    required this.description,
    required this.hasAudio,
    required this.hasVisual,
    required this.hasText,
    required this.predictedScore,
  });

  Map<String, dynamic> toJson() => {
    'coalitionCode': coalitionCode,
    'label': label,
    'description': description,
    'hasAudio': hasAudio,
    'hasVisual': hasVisual,
    'hasText': hasText,
    'predictedScore': predictedScore,
  };

  factory CoalitionStepScore.fromJson(Map<String, dynamic> json) => CoalitionStepScore(
    coalitionCode: json['coalitionCode'] as String? ?? '',
    label: json['label'] as String? ?? '',
    description: json['description'] as String? ?? '',
    hasAudio: json['hasAudio'] as bool? ?? false,
    hasVisual: json['hasVisual'] as bool? ?? false,
    hasText: json['hasText'] as bool? ?? false,
    predictedScore: (json['predictedScore'] as num?)?.toDouble() ?? 0.0,
  );
}

class MultimodalInspectionData {
  final String participantId;
  final String? videoPath;
  final bool isFromRealVideo;
  final double videoDurationSec;

  // Visual / Face Detection Metrics
  final int framesAnalyzed;
  final int facesDetected;
  final double faceDetectionRatePct;
  final double avgFaceConfidence;
  final double avgHeadPitchDeg;
  final double avgHeadYawDeg;
  final String facialAffectTitle;
  final String facialAffectDescription;
  final Map<String, double> actionUnitScores;
  final List<VisualFrameInspection> visualFrames;

  // Audio / Waveform & Prosody Metrics
  final int audioSampleRate;
  final int totalAudioSamples;
  final List<double> audioWaveformBars;
  final List<double> pitchContourHz;
  final double avgPitchHz;
  final double pitchStdHz;
  final double voicedRatioPct;
  final double pauseRatioPct;
  final double jitterPct;
  final double shimmerPct;
  final String vocalProsodyTitle;
  final String vocalProsodyDescription;

  // Text / Transcript & Psycholinguistics
  final String fullTranscript;
  final String translatedTranscript;
  final String transcriptLanguage;
  final List<TranscriptSegmentItem> transcriptSegments;
  final List<String> detectedKeywords;
  final double emotionalValence;
  final int selfPronounCount;
  final String linguisticTitle;
  final String linguisticDescription;
  final bool isExplicitTranscript;
  final bool isWhisperTranscribed;

  // Neural Feature & Shapley Calculation Transparency
  final List<double> sampleVisualVector;
  final List<double> sampleAudioVector;
  final List<double> sampleTextVector;
  final double audioLatentNorm;
  final double visualLatentNorm;
  final double textLatentNorm;
  final List<CoalitionStepScore> coalitionScores;

  const MultimodalInspectionData({
    required this.participantId,
    this.videoPath,
    required this.isFromRealVideo,
    required this.videoDurationSec,
    required this.framesAnalyzed,
    required this.facesDetected,
    required this.faceDetectionRatePct,
    required this.avgFaceConfidence,
    required this.avgHeadPitchDeg,
    required this.avgHeadYawDeg,
    required this.facialAffectTitle,
    required this.facialAffectDescription,
    required this.actionUnitScores,
    required this.visualFrames,
    required this.audioSampleRate,
    required this.totalAudioSamples,
    required this.audioWaveformBars,
    required this.pitchContourHz,
    required this.avgPitchHz,
    required this.pitchStdHz,
    required this.voicedRatioPct,
    required this.pauseRatioPct,
    required this.jitterPct,
    required this.shimmerPct,
    required this.vocalProsodyTitle,
    required this.vocalProsodyDescription,
    required this.fullTranscript,
    this.translatedTranscript = '',
    this.transcriptLanguage = 'id',
    required this.transcriptSegments,
    required this.detectedKeywords,
    required this.emotionalValence,
    required this.selfPronounCount,
    required this.linguisticTitle,
    required this.linguisticDescription,
    this.isExplicitTranscript = false,
    this.isWhisperTranscribed = false,
    required this.sampleVisualVector,
    required this.sampleAudioVector,
    required this.sampleTextVector,
    this.audioLatentNorm = 1.0,
    this.visualLatentNorm = 1.0,
    this.textLatentNorm = 1.0,
    this.coalitionScores = const [],
  });

  MultimodalInspectionData copyWithCalculation({
    double? audioLatentNorm,
    double? visualLatentNorm,
    double? textLatentNorm,
    List<CoalitionStepScore>? coalitionScores,
  }) {
    return MultimodalInspectionData(
      participantId: participantId,
      videoPath: videoPath,
      isFromRealVideo: isFromRealVideo,
      videoDurationSec: videoDurationSec,
      framesAnalyzed: framesAnalyzed,
      facesDetected: facesDetected,
      faceDetectionRatePct: faceDetectionRatePct,
      avgFaceConfidence: avgFaceConfidence,
      avgHeadPitchDeg: avgHeadPitchDeg,
      avgHeadYawDeg: avgHeadYawDeg,
      facialAffectTitle: facialAffectTitle,
      facialAffectDescription: facialAffectDescription,
      actionUnitScores: actionUnitScores,
      visualFrames: visualFrames,
      audioSampleRate: audioSampleRate,
      totalAudioSamples: totalAudioSamples,
      audioWaveformBars: audioWaveformBars,
      pitchContourHz: pitchContourHz,
      avgPitchHz: avgPitchHz,
      pitchStdHz: pitchStdHz,
      voicedRatioPct: voicedRatioPct,
      pauseRatioPct: pauseRatioPct,
      jitterPct: jitterPct,
      shimmerPct: shimmerPct,
      vocalProsodyTitle: vocalProsodyTitle,
      vocalProsodyDescription: vocalProsodyDescription,
      fullTranscript: fullTranscript,
      translatedTranscript: translatedTranscript,
      transcriptLanguage: transcriptLanguage,
      transcriptSegments: transcriptSegments,
      detectedKeywords: detectedKeywords,
      emotionalValence: emotionalValence,
      selfPronounCount: selfPronounCount,
      linguisticTitle: linguisticTitle,
      linguisticDescription: linguisticDescription,
      isExplicitTranscript: isExplicitTranscript,
      isWhisperTranscribed: isWhisperTranscribed,
      sampleVisualVector: sampleVisualVector,
      sampleAudioVector: sampleAudioVector,
      sampleTextVector: sampleTextVector,
      audioLatentNorm: audioLatentNorm ?? this.audioLatentNorm,
      visualLatentNorm: visualLatentNorm ?? this.visualLatentNorm,
      textLatentNorm: textLatentNorm ?? this.textLatentNorm,
      coalitionScores: coalitionScores ?? this.coalitionScores,
    );
  }

  MultimodalInspectionData copyWith({
    String? videoPath,
  }) {
    return MultimodalInspectionData(
      participantId: participantId,
      videoPath: videoPath ?? this.videoPath,
      isFromRealVideo: isFromRealVideo,
      videoDurationSec: videoDurationSec,
      framesAnalyzed: framesAnalyzed,
      facesDetected: facesDetected,
      faceDetectionRatePct: faceDetectionRatePct,
      avgFaceConfidence: avgFaceConfidence,
      avgHeadPitchDeg: avgHeadPitchDeg,
      avgHeadYawDeg: avgHeadYawDeg,
      facialAffectTitle: facialAffectTitle,
      facialAffectDescription: facialAffectDescription,
      actionUnitScores: actionUnitScores,
      visualFrames: visualFrames,
      audioSampleRate: audioSampleRate,
      totalAudioSamples: totalAudioSamples,
      audioWaveformBars: audioWaveformBars,
      pitchContourHz: pitchContourHz,
      avgPitchHz: avgPitchHz,
      pitchStdHz: pitchStdHz,
      voicedRatioPct: voicedRatioPct,
      pauseRatioPct: pauseRatioPct,
      jitterPct: jitterPct,
      shimmerPct: shimmerPct,
      vocalProsodyTitle: vocalProsodyTitle,
      vocalProsodyDescription: vocalProsodyDescription,
      fullTranscript: fullTranscript,
      translatedTranscript: translatedTranscript,
      transcriptLanguage: transcriptLanguage,
      transcriptSegments: transcriptSegments,
      detectedKeywords: detectedKeywords,
      emotionalValence: emotionalValence,
      selfPronounCount: selfPronounCount,
      linguisticTitle: linguisticTitle,
      linguisticDescription: linguisticDescription,
      isExplicitTranscript: isExplicitTranscript,
      isWhisperTranscribed: isWhisperTranscribed,
      sampleVisualVector: sampleVisualVector,
      sampleAudioVector: sampleAudioVector,
      sampleTextVector: sampleTextVector,
      audioLatentNorm: audioLatentNorm,
      visualLatentNorm: visualLatentNorm,
      textLatentNorm: textLatentNorm,
      coalitionScores: coalitionScores,
    );
  }

  Map<String, dynamic> toJson() => {
    'participantId': participantId,
    'videoPath': videoPath,
    'isFromRealVideo': isFromRealVideo,
    'videoDurationSec': videoDurationSec,
    'framesAnalyzed': framesAnalyzed,
    'facesDetected': facesDetected,
    'faceDetectionRatePct': faceDetectionRatePct,
    'avgFaceConfidence': avgFaceConfidence,
    'avgHeadPitchDeg': avgHeadPitchDeg,
    'avgHeadYawDeg': avgHeadYawDeg,
    'facialAffectTitle': facialAffectTitle,
    'facialAffectDescription': facialAffectDescription,
    'actionUnitScores': actionUnitScores,
    'visualFrames': visualFrames.map((e) => e.toJson()).toList(),
    'audioSampleRate': audioSampleRate,
    'totalAudioSamples': totalAudioSamples,
    'audioWaveformBars': audioWaveformBars,
    'pitchContourHz': pitchContourHz,
    'avgPitchHz': avgPitchHz,
    'pitchStdHz': pitchStdHz,
    'voicedRatioPct': voicedRatioPct,
    'pauseRatioPct': pauseRatioPct,
    'jitterPct': jitterPct,
    'shimmerPct': shimmerPct,
    'vocalProsodyTitle': vocalProsodyTitle,
    'vocalProsodyDescription': vocalProsodyDescription,
    'fullTranscript': fullTranscript,
    'translatedTranscript': translatedTranscript,
    'transcriptLanguage': transcriptLanguage,
    'transcriptSegments': transcriptSegments.map((e) => e.toJson()).toList(),
    'detectedKeywords': detectedKeywords,
    'emotionalValence': emotionalValence,
    'selfPronounCount': selfPronounCount,
    'linguisticTitle': linguisticTitle,
    'linguisticDescription': linguisticDescription,
    'isExplicitTranscript': isExplicitTranscript,
    'isWhisperTranscribed': isWhisperTranscribed,
    'sampleVisualVector': sampleVisualVector,
    'sampleAudioVector': sampleAudioVector,
    'sampleTextVector': sampleTextVector,
    'audioLatentNorm': audioLatentNorm,
    'visualLatentNorm': visualLatentNorm,
    'textLatentNorm': textLatentNorm,
    'coalitionScores': coalitionScores.map((e) => e.toJson()).toList(),
  };

  factory MultimodalInspectionData.fromJson(Map<String, dynamic> json) => MultimodalInspectionData(
    participantId: json['participantId'] as String? ?? '',
    videoPath: json['videoPath'] as String?,
    isFromRealVideo: json['isFromRealVideo'] as bool? ?? false,
    videoDurationSec: (json['videoDurationSec'] as num?)?.toDouble() ?? 0.0,
    framesAnalyzed: json['framesAnalyzed'] as int? ?? 0,
    facesDetected: json['facesDetected'] as int? ?? 0,
    faceDetectionRatePct: (json['faceDetectionRatePct'] as num?)?.toDouble() ?? 0.0,
    avgFaceConfidence: (json['avgFaceConfidence'] as num?)?.toDouble() ?? 0.0,
    avgHeadPitchDeg: (json['avgHeadPitchDeg'] as num?)?.toDouble() ?? 0.0,
    avgHeadYawDeg: (json['avgHeadYawDeg'] as num?)?.toDouble() ?? 0.0,
    facialAffectTitle: json['facialAffectTitle'] as String? ?? '',
    facialAffectDescription: json['facialAffectDescription'] as String? ?? '',
    actionUnitScores: (json['actionUnitScores'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ) ??
        const {},
    visualFrames: (json['visualFrames'] as List<dynamic>?)
            ?.map((e) => VisualFrameInspection.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    audioSampleRate: json['audioSampleRate'] as int? ?? 16000,
    totalAudioSamples: json['totalAudioSamples'] as int? ?? 0,
    audioWaveformBars: (json['audioWaveformBars'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    pitchContourHz: (json['pitchContourHz'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    avgPitchHz: (json['avgPitchHz'] as num?)?.toDouble() ?? 0.0,
    pitchStdHz: (json['pitchStdHz'] as num?)?.toDouble() ?? 0.0,
    voicedRatioPct: (json['voicedRatioPct'] as num?)?.toDouble() ?? 0.0,
    pauseRatioPct: (json['pauseRatioPct'] as num?)?.toDouble() ?? 0.0,
    jitterPct: (json['jitterPct'] as num?)?.toDouble() ?? 0.0,
    shimmerPct: (json['shimmerPct'] as num?)?.toDouble() ?? 0.0,
    vocalProsodyTitle: json['vocalProsodyTitle'] as String? ?? '',
    vocalProsodyDescription: json['vocalProsodyDescription'] as String? ?? '',
    fullTranscript: json['fullTranscript'] as String? ?? '',
    translatedTranscript: json['translatedTranscript'] as String? ?? '',
    transcriptLanguage: json['transcriptLanguage'] as String? ?? 'id',
    transcriptSegments: (json['transcriptSegments'] as List<dynamic>?)
            ?.map((e) => TranscriptSegmentItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    detectedKeywords: (json['detectedKeywords'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    emotionalValence: (json['emotionalValence'] as num?)?.toDouble() ?? 0.0,
    selfPronounCount: json['selfPronounCount'] as int? ?? 0,
    linguisticTitle: json['linguisticTitle'] as String? ?? '',
    linguisticDescription: json['linguisticDescription'] as String? ?? '',
    isExplicitTranscript: json['isExplicitTranscript'] as bool? ?? false,
    isWhisperTranscribed: json['isWhisperTranscribed'] as bool? ?? false,
    sampleVisualVector: (json['sampleVisualVector'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    sampleAudioVector: (json['sampleAudioVector'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    sampleTextVector: (json['sampleTextVector'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const [],
    audioLatentNorm: (json['audioLatentNorm'] as num?)?.toDouble() ?? 1.0,
    visualLatentNorm: (json['visualLatentNorm'] as num?)?.toDouble() ?? 1.0,
    textLatentNorm: (json['textLatentNorm'] as num?)?.toDouble() ?? 1.0,
    coalitionScores: (json['coalitionScores'] as List<dynamic>?)
            ?.map((e) => CoalitionStepScore.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}
