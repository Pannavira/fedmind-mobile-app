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
}

class TranscriptSegmentItem {
  final String timeRangeLabel;
  final String text;
  final List<String> detectedKeywords;
  final String prosodyNote;

  const TranscriptSegmentItem({
    required this.timeRangeLabel,
    required this.text,
    this.detectedKeywords = const [],
    this.prosodyNote = '',
  });
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
  final List<TranscriptSegmentItem> transcriptSegments;
  final List<String> detectedKeywords;
  final double emotionalValence;
  final int selfPronounCount;
  final String linguisticTitle;
  final String linguisticDescription;

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
    required this.transcriptSegments,
    required this.detectedKeywords,
    required this.emotionalValence,
    required this.selfPronounCount,
    required this.linguisticTitle,
    required this.linguisticDescription,
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
      transcriptSegments: transcriptSegments,
      detectedKeywords: detectedKeywords,
      emotionalValence: emotionalValence,
      selfPronounCount: selfPronounCount,
      linguisticTitle: linguisticTitle,
      linguisticDescription: linguisticDescription,
      sampleVisualVector: sampleVisualVector,
      sampleAudioVector: sampleAudioVector,
      sampleTextVector: sampleTextVector,
      audioLatentNorm: audioLatentNorm ?? this.audioLatentNorm,
      visualLatentNorm: visualLatentNorm ?? this.visualLatentNorm,
      textLatentNorm: textLatentNorm ?? this.textLatentNorm,
      coalitionScores: coalitionScores ?? this.coalitionScores,
    );
  }
}
