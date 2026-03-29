import 'dart:io';
import 'dart:math';
import 'dart:typed_data';import 'package:flutter/material.dart'; // Required for Rect
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class BrailleDetection {
  final Rect rect;
  final String label;
  final double score;

  BrailleDetection({required this.rect, required this.label, required this.score});
}

typedef SectionCallback = void Function(
    int index, int total, double topNorm, double bottomNorm, int found);

class TfliteHelper {
  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;

  final List<String> _labels = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'
  ];

  // Auto-detected per model
  bool _outputTransposed = false; // true → [batch, anchors, features]
  bool _needsSigmoid = false;     // true → scores are raw logits
  int _numClasses = 26;           // detected from output shape

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/best_3_float16.tflite');
      _inputShape  = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;

      // --- Auto-detect output format ---
      // YOLOv8 output is either:
      //   [1, 4+classes, anchors]  → dim1 < dim2  (standard)
      //   [1, anchors, 4+classes]  → dim1 > dim2  (transposed)
      _outputTransposed = _outputShape![1] > _outputShape![2];
      final int featureDim = _outputTransposed ? _outputShape![2] : _outputShape![1];
      _numClasses = featureDim - 4;

      print('=== MODEL INFO ===');
      print('Input shape : $_inputShape');
      print('Output shape: $_outputShape');
      print('Format      : ${_outputTransposed ? "TRANSPOSED [batch,anchors,features]" : "STANDARD [batch,features,anchors]"}');
      print('Num classes : $_numClasses (labels list has ${_labels.length})');
      if (_numClasses != _labels.length) {
        print('⚠️  CLASS COUNT MISMATCH — model has $_numClasses classes but labels list has ${_labels.length}');
      }
      print('Input type  : ${_interpreter!.getInputTensor(0).type}');
      print('==================');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  Future<List<BrailleDetection>> processImage(
    File imageFile, {
    SectionCallback? onSectionDone,
  }) async {
    if (_interpreter == null) return [];

    try {
      final bytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return [];

      final strips = _segmentRows(originalImage);
      final int total = strips.length;
      print('Fixed tiling: $total section(s)');

      final List<BrailleDetection> allDetections = [];
      for (int i = 0; i < strips.length; i++) {
        final strip     = strips[i];
        final int yOff  = strip['yOffset'] as int;
        final img.Image stripImg = strip['image'] as img.Image;

        final sectionDetections = _runModelOnStrip(stripImg, yOff, originalImage.height);
        allDetections.addAll(sectionDetections);

        final double topNorm    = yOff / originalImage.height;
        final double bottomNorm = (yOff + stripImg.height) / originalImage.height;
        onSectionDone?.call(i, total, topNorm, bottomNorm, sectionDetections.length);
      }

      // --- DEBUG ---
      print('Total raw detections: ${allDetections.length}');
      // --- END DEBUG ---

      return _applyNMS(allDetections);
    } catch (e) {
      print('Error: $e');
      return [];
    }
  }

  /// Splits the image into N equal horizontal sections with 15% overlap so
  /// no character is ever cut at a section boundary.
  /// N is chosen automatically based on the image aspect ratio:
  ///   roughly square → 1 section, tall page → more sections.
  List<Map<String, dynamic>> _segmentRows(img.Image image) {
    final int w = image.width;
    final int h = image.height;

    // Auto-calculate N: one section per image-width worth of height.
    // Portrait pages get at least 3 sections; landscape/square get 1.
    final int n = h > w
        ? (h / w).ceil().clamp(3, 8)
        : 2;

    final int stride  = h ~/ n;
    final int overlap = (stride * 0.15).round(); // 15% overlap on each edge

    final List<Map<String, dynamic>> strips = [];
    for (int i = 0; i < n; i++) {
      final int top    = (i * stride - overlap).clamp(0, h - 1);
      final int bottom = ((i + 1) * stride + overlap).clamp(0, h);
      strips.add({
        'image'  : img.copyCrop(image, x: 0, y: top, width: w, height: bottom - top),
        'yOffset': top,
      });
    }

    print('Fixed tiling: ${n} section(s) | image ${w}x${h} | stride=$stride overlap=$overlap');
    return strips;
  }

  /// Runs the model on a single image strip using letterbox preprocessing:
  /// scales the strip to fit within the model input while preserving aspect
  /// ratio, pads the remainder with grey (YOLOv8 default = 114,114,114),
  /// then maps detections back to full-image normalised coordinates.
  List<BrailleDetection> _runModelOnStrip(
      img.Image strip, int yOffset, int fullImageHeight) {
    final int mW = _inputShape![2]; // model input width  (e.g. 320)
    final int mH = _inputShape![1]; // model input height (e.g. 320)

    // --- Letterbox ---
    final double scale = min(mW / strip.width, mH / strip.height);
    final int newW = (strip.width  * scale).round();
    final int newH = (strip.height * scale).round();
    final int padX = ((mW - newW) / 2).round(); // pixels of padding on each side
    final int padY = ((mH - newH) / 2).round();

    final img.Image resized = img.copyResize(strip, width: newW, height: newH);
    // Fill canvas with YOLOv8 letterbox grey
    final img.Image canvas = img.Image(width: mW, height: mH)
      ..clear(img.ColorRgb8(114, 114, 114));
    img.compositeImage(canvas, resized, dstX: padX, dstY: padY);

    var input = Float32List(mH * mW * 3);
    int idx = 0;
    for (int y = 0; y < mH; y++) {
      for (int x = 0; x < mW; x++) {
        final p = canvas.getPixel(x, y);
        input[idx++] = p.r / 255.0;
        input[idx++] = p.g / 255.0;
        input[idx++] = p.b / 255.0;
      }
    }

    var output = List.generate(_outputShape![0], (b) =>
        List.generate(_outputShape![1], (c) =>
            List.filled(_outputShape![2], 0.0)));

    _interpreter!.run(input.reshape([1, mH, mW, 3]), output);

    // --- DEBUG ---
    print('=== DEBUG STRIP (yOffset=$yOffset) ===');
    print('Strip size: ${strip.width}x${strip.height} → scale=$scale canvas ${newW}x${newH} padX=$padX padY=$padY');
    print('Format: ${_outputTransposed ? "transposed" : "standard"} | needsSigmoid: $_needsSigmoid');

    // Helper to read score value regardless of format
    double rawVal(int anchor, int feature) => _outputTransposed
        ? output[0][anchor][feature]
        : output[0][feature][anchor];

    final int numAnchors = _outputTransposed ? _outputShape![1] : _outputShape![2];

    // Find highest raw score to auto-detect if sigmoid is needed
    double globalMaxRaw = 0.0;
    int globalMaxAnchor = -1;
    int globalMaxClass  = -1;
    for (int i = 0; i < numAnchors; i++) {
      for (int c = 4; c < 4 + _numClasses; c++) {
        final double s = rawVal(i, c);
        if (s > globalMaxRaw) { globalMaxRaw = s; globalMaxAnchor = i; globalMaxClass = c - 4; }
      }
    }
    // If highest raw score > 1, scores are logits → need sigmoid
    _needsSigmoid = globalMaxRaw > 1.0;
    final double displayScore = _needsSigmoid ? (1.0 / (1.0 + exp(-globalMaxRaw))) : globalMaxRaw;
    print('Highest raw score: $globalMaxRaw → after sigmoid check: ${displayScore.toStringAsFixed(4)} | class=$globalMaxClass (${globalMaxClass >= 0 && globalMaxClass < _labels.length ? _labels[globalMaxClass] : "?"})');
    print('======================================');
    // --- END DEBUG ---

    // --- Coordinate conversion ---
    final double stripH = strip.height.toDouble();
    final double yFrac  = stripH / fullImageHeight;
    final double yShift = yOffset / fullImageHeight;

    final List<BrailleDetection> detections = [];
    const double threshold = 0.05;

    for (int i = 0; i < numAnchors; i++) {
      double maxScore = 0.0;
      int classId = -1;

      for (int c = 4; c < 4 + _numClasses; c++) {
        double s = rawVal(i, c);
        if (_needsSigmoid) s = 1.0 / (1.0 + exp(-s));
        if (s > maxScore) { maxScore = s; classId = c - 4; }
      }

      if (maxScore > threshold && classId < _labels.length) {
        final double cxPx = rawVal(i, 0) * mW;
        final double cyPx = rawVal(i, 1) * mH;
        final double  wPx = rawVal(i, 2) * mW;
        final double  hPx = rawVal(i, 3) * mH;

        final double cxScaled = cxPx - padX;
        final double cyScaled = cyPx - padY;

        final double cxStrip = cxScaled / newW;
        final double cyStrip = cyScaled / newH;
        final double  wStrip = wPx / newW;
        final double  hStrip = hPx / newH;

        final double cyFull = cyStrip * yFrac + yShift;
        final double  hFull = hStrip  * yFrac;

        if (cxStrip < 0 || cxStrip > 1 || cyStrip < 0 || cyStrip > 1) continue;

        detections.add(BrailleDetection(
          rect: Rect.fromLTWH(cxStrip - wStrip / 2, cyFull - hFull / 2, wStrip, hFull),
          label: _labels[classId],
          score: maxScore,
        ));
      }
    }

    return detections;
  }

  double _iou(Rect a, Rect b) {
    final intersection = a.intersect(b);
    if (intersection.width <= 0 || intersection.height <= 0) return 0.0;
    final intersectionArea = intersection.width * intersection.height;
    final unionArea = a.width * a.height + b.width * b.height - intersectionArea;
    return unionArea <= 0 ? 0.0 : intersectionArea / unionArea;
  }

  List<BrailleDetection> _applyNMS(List<BrailleDetection> detections) {
    detections.sort((a, b) => b.score.compareTo(a.score));
    final List<BrailleDetection> result = [];
    while (detections.isNotEmpty) {
      final first = detections.removeAt(0);
      result.add(first);
      detections.removeWhere((next) => _iou(first.rect, next.rect) > 0.35);
    }
    return result;
  }

  void close() => _interpreter?.close();
}
