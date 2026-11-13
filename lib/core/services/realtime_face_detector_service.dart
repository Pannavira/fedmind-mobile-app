import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Status keberadaan dan posisi wajah secara real-time pada pratinjau kamera klinis.
enum RealtimeFaceStatus {
  checking,
  detected,
  outOfZone,
  noFace,
  recordingActive,
}

/// Hasil evaluasi keberadaan wajah pada satu frame kamera.
class RealtimeFaceEvaluation {
  final RealtimeFaceStatus status;
  final int faceCount;
  final Rect? normalizedBox;
  final String message;

  const RealtimeFaceEvaluation({
    required this.status,
    required this.faceCount,
    this.normalizedBox,
    required this.message,
  });

  bool get isFacePresent =>
      status == RealtimeFaceStatus.detected ||
      status == RealtimeFaceStatus.outOfZone;
}

/// Layanan deteksi wajah on-device real-time untuk pratinjau [CameraController]
/// menggunakan Google ML Kit Face Detection.
class RealtimeFaceDetectorService {
  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  final FaceDetector _detector;
  bool _isClosed = false;

  RealtimeFaceDetectorService({FaceDetectorOptions? options})
      : _detector = FaceDetector(
          options: options ??
              FaceDetectorOptions(
                performanceMode: FaceDetectorMode.fast,
                enableContours: false,
                enableLandmarks: false,
                enableClassification: false,
                minFaceSize: 0.14,
              ),
        );

  /// Mengevaluasi frame kamera mentah menjadi status keberadaan wajah [RealtimeFaceEvaluation].
  Future<RealtimeFaceEvaluation?> processCameraImage({
    required CameraImage image,
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) async {
    if (_isClosed) return null;

    final converted = _buildInputImage(image, camera, deviceOrientation);
    if (converted == null) return null;

    final faces = await _detector.processImage(converted.inputImage);
    if (_isClosed) return null;

    return evaluateBoundingBoxes(
      boundingBoxes: faces.map((f) => f.boundingBox).toList(),
      rotatedImageSize: converted.rotatedSize,
      isFrontCamera: camera.lensDirection == CameraLensDirection.front,
    );
  }

  /// Mengevaluasi posisi dan ukuran wajah terhadap bingkai oval FACS di tengah layar.
  /// Dipisahkan sebagai fungsi murni agar mudah diuji secara unit test.
  static RealtimeFaceEvaluation evaluateBoundingBoxes({
    required List<Rect> boundingBoxes,
    required Size rotatedImageSize,
    required bool isFrontCamera,
  }) {
    if (boundingBoxes.isEmpty ||
        rotatedImageSize.width <= 0 ||
        rotatedImageSize.height <= 0) {
      return const RealtimeFaceEvaluation(
        status: RealtimeFaceStatus.noFace,
        faceCount: 0,
        message: 'Wajah tidak terlihat di kamera',
      );
    }

    Rect primaryBox = boundingBoxes.first;
    double maxArea = primaryBox.width * primaryBox.height;
    for (int i = 1; i < boundingBoxes.length; i++) {
      final candidate = boundingBoxes[i];
      final area = candidate.width * candidate.height;
      if (area > maxArea) {
        maxArea = area;
        primaryBox = candidate;
      }
    }

    final rawLeft =
        (primaryBox.left / rotatedImageSize.width).clamp(0.0, 1.0);
    final rawRight =
        (primaryBox.right / rotatedImageSize.width).clamp(0.0, 1.0);
    final normTop =
        (primaryBox.top / rotatedImageSize.height).clamp(0.0, 1.0);
    final normBottom =
        (primaryBox.bottom / rotatedImageSize.height).clamp(0.0, 1.0);

    final normLeft = isFrontCamera ? (1.0 - rawRight) : rawLeft;
    final normRight = isFrontCamera ? (1.0 - rawLeft) : rawRight;
    final normBox = Rect.fromLTRB(normLeft, normTop, normRight, normBottom);

    final centerX = (normBox.left + normBox.right) * 0.5;
    final centerY = (normBox.top + normBox.bottom) * 0.5;
    final heightRatio = normBox.height;

    final bool tooSmall = heightRatio < 0.14;
    final bool outsideCenterZone =
        centerX < 0.22 || centerX > 0.78 || centerY < 0.16 || centerY > 0.84;

    if (tooSmall || outsideCenterZone) {
      return RealtimeFaceEvaluation(
        status: RealtimeFaceStatus.outOfZone,
        faceCount: boundingBoxes.length,
        normalizedBox: normBox,
        message: tooSmall
            ? 'Dekatkan wajah ke kamera (di dalam oval)'
            : 'Posisikan wajah di dalam bingkai oval',
      );
    }

    return RealtimeFaceEvaluation(
      status: RealtimeFaceStatus.detected,
      faceCount: boundingBoxes.length,
      normalizedBox: normBox,
      message: 'Wajah terdeteksi • Posisi FACS siap',
    );
  }

  ({InputImage inputImage, Size rotatedSize})? _buildInputImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final InputImageRotation? rotation =
        _resolveRotation(camera, deviceOrientation);
    if (rotation == null) return null;

    final bool isRotated90Or270 =
        rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg;
    final rotatedSize = isRotated90Or270
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());

    if (Platform.isIOS) {
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format != InputImageFormat.bgra8888 || image.planes.isEmpty) {
        return null;
      }
      final plane = image.planes.first;
      return (
        inputImage: InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format!,
            bytesPerRow: plane.bytesPerRow,
          ),
        ),
        rotatedSize: rotatedSize,
      );
    }

    if (Platform.isAndroid) {
      final Uint8List? nv21Bytes;
      if (image.planes.length == 1) {
        nv21Bytes = image.planes.first.bytes;
      } else if (image.planes.length >= 3) {
        nv21Bytes = _yuv420ToNv21(image);
      } else {
        return null;
      }

      return (
        inputImage: InputImage.fromBytes(
          bytes: nv21Bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.width,
          ),
        ),
        rotatedSize: rotatedSize,
      );
    }

    return null;
  }

  static InputImageRotation? _resolveRotation(
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensorOrientation);
    }
    var rotationCompensation = _orientations[deviceOrientation];
    if (rotationCompensation == null) return null;

    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation =
          (sensorOrientation - rotationCompensation + 360) % 360;
    }
    return InputImageRotationValue.fromRawValue(rotationCompensation);
  }

  static Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int ySize = width * height;
    final int uvSize = ySize ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int yPixelStride = yPlane.bytesPerPixel ?? 1;

    int outIdx = 0;
    if (yRowStride == width && yPixelStride == 1) {
      nv21.setRange(0, ySize, yPlane.bytes);
      outIdx = ySize;
    } else {
      for (int row = 0; row < height; row++) {
        final rowOffset = row * yRowStride;
        for (int col = 0; col < width; col++) {
          nv21[outIdx++] = yPlane.bytes[rowOffset + col * yPixelStride];
        }
      }
    }

    final int uvRowStride = vPlane.bytesPerRow;
    final int uvPixelStride = vPlane.bytesPerPixel ?? 1;
    final int uvWidth = width ~/ 2;
    final int uvHeight = height ~/ 2;

    for (int row = 0; row < uvHeight; row++) {
      final vRowOffset = row * uvRowStride;
      final uRowOffset = row * uPlane.bytesPerRow;
      for (int col = 0; col < uvWidth; col++) {
        final vIdx = vRowOffset + col * uvPixelStride;
        final uIdx = uRowOffset + col * (uPlane.bytesPerPixel ?? 1);
        nv21[outIdx++] = vPlane.bytes[vIdx];
        nv21[outIdx++] = uPlane.bytes[uIdx];
      }
    }

    return nv21;
  }

  Future<void> dispose() async {
    if (_isClosed) return;
    _isClosed = true;
    await _detector.close();
  }
}

