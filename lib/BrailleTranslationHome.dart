import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'image_picker_helper.dart';
import 'learn_braille.dart';
import 'correction_helper.dart'; // Changed from llm_helper.dart
import 'tflite_helper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Braille Translator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const BrailleTranslatorHome(),
    );
  }
}

class BrailleTranslatorHome extends StatefulWidget {
  const BrailleTranslatorHome({super.key});

  @override
  State<BrailleTranslatorHome> createState() => _BrailleTranslatorHomeState();
}

class _BrailleTranslatorHomeState extends State<BrailleTranslatorHome>
    with SingleTickerProviderStateMixin {
  final ImagePickerHelper _imagePickerHelper = ImagePickerHelper();
  final TfliteHelper _tfliteHelper = TfliteHelper();

  File? _selectedImage;
  Size? _imageSize;
  List<BrailleDetection> _detections = [];
  bool _isProcessing = false;
  String _statusMessage = "Upload or take a photo of braille to translate.";

  // Section progress tracking
  List<_SectionStatus> _sections = [];

  // Correction suggestion
  String? _correctionSuggestion;
  bool _isLoadingCorrection = false;

  // Processing timer
  Stopwatch _stopwatch = Stopwatch();
  String? _processingTime;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initModel();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _initModel() async {
    await _tfliteHelper.loadModel();
  }

  @override
  void dispose() {
    _tfliteHelper.close();
    _fadeController.dispose();
    super.dispose();
  }

  /// Returns null if resolution is acceptable, or a warning message if not.
  String? _checkResolution(Size imgSize) {
    final int w = imgSize.width.toInt();
    final int h = imgSize.height.toInt();
    final int totalPixels = w * h;
    final int shortSide = w < h ? w : h;

    if (shortSide < 240) {
      return 'Image is very small (${w}×${h} px). Braille dots may be too tiny '
          'for the model to detect reliably. Please retake at a higher resolution.';
    }
    if (totalPixels < 200000) {   // < 0.2 MP
      return 'Image resolution is low (${w}×${h} px, '
          '${(totalPixels / 1000000).toStringAsFixed(2)} MP). '
          'Consider retaking the photo closer to the page.';
    }
    return null;
  }

  Future<void> _handleImageSelection(Future<File?> Function() pickMethod) async {
    final file = await pickMethod();
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
    final frame = await codec.getNextFrame();
    final imgSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());

    // Show image immediately so it's visible behind any dialog
    setState(() {
      _selectedImage = file;
      _imageSize = imgSize;
      _detections = [];
      _sections = [];
      _correctionSuggestion = null;
      _isLoadingCorrection = false;
      _statusMessage = "Checking image...";
    });

    final String? warning = _checkResolution(imgSize);
    if (warning != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(child: Text(warning, style: const TextStyle(fontSize: 13))),
            ],
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    _startProcessing(file);
  }

  Future<void> _startProcessing(File file) async {
    _fadeController.reset();
    _stopwatch.reset();
    _stopwatch.start();
    setState(() {
      _isProcessing = true;
      _processingTime = null;
      _statusMessage = "Processing image...";
    });
    await WidgetsBinding.instance.endOfFrame;

    final results = await _tfliteHelper.processImage(
      file,
      onSectionDone: (index, total, topNorm, bottomNorm, found) {
        setState(() {
          if (_sections.isEmpty) {
            _sections = List.generate(
              total,
              (i) => _SectionStatus(index: i, total: total),
            );
          }
          _sections[index] = _SectionStatus(
            index: index,
            total: total,
            topNorm: topNorm,
            bottomNorm: bottomNorm,
            detectionsFound: found,
            isDone: true,
          );
        });
      },
    );

    _stopwatch.stop();
    final elapsed = _stopwatch.elapsedMilliseconds;
    final timeStr = elapsed >= 1000
        ? '${(elapsed / 1000).toStringAsFixed(1)}s'
        : '${elapsed}ms';

    setState(() {
      _detections = results;
      _isProcessing = false;
      _processingTime = timeStr;
      _statusMessage = results.isEmpty
          ? "No Braille characters detected."
          : "Translation complete.";
      _fadeController.forward();
    });
  }

  /// Converts detections to a readable string using spatial coordinates.
  String _buildReadableText(List<BrailleDetection> detections) {
    if (detections.isEmpty) return '';

    double avgW = detections.map((d) => d.rect.width).reduce((a, b) => a + b) / detections.length;
    double avgH = detections.map((d) => d.rect.height).reduce((a, b) => a + b) / detections.length;

    final sorted = List<BrailleDetection>.from(detections)
      ..sort((a, b) => a.rect.center.dy.compareTo(b.rect.center.dy));

    final List<List<BrailleDetection>> rows = [];
    List<BrailleDetection> currentRow = [sorted.first];
    for (int i = 1; i < sorted.length; i++) {
      final dy = sorted[i].rect.center.dy - sorted[i - 1].rect.center.dy;
      if (dy > avgH * 0.6) {
        rows.add(currentRow);
        currentRow = [];
      }
      currentRow.add(sorted[i]);
    }
    rows.add(currentRow);

    final buffer = StringBuffer();
    for (int r = 0; r < rows.length; r++) {
      if (r > 0) buffer.write('\n');
      final row = List<BrailleDetection>.from(rows[r])
        ..sort((a, b) => a.rect.left.compareTo(b.rect.left));

      buffer.write(row.first.label);
      for (int i = 1; i < row.length; i++) {
        final gap = row[i].rect.left - row[i - 1].rect.right;
        if (gap > avgW * 1.5) {
          buffer.write(' ');       
        } else if (gap > avgW * 0.5) {
          buffer.write(' ');       
        }
        buffer.write(row[i].label);
      }
    }
    return buffer.toString();
  }

  void _clear() {
    setState(() {
      _selectedImage = null;
      _imageSize = null;
      _detections = [];
      _sections = [];
      _correctionSuggestion = null;
      _isLoadingCorrection = false;
      _statusMessage = "Upload or take a photo of braille to translate.";
      _fadeController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double displayWidth = MediaQuery.of(context).size.width - 32;
    const double labelPad = 24.0;
    final double displayHeight = _imageSize != null
        ? (displayWidth * _imageSize!.height / _imageSize!.width)
            .clamp(200.0, double.infinity)
        : displayWidth;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Braille Translator'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onPrimaryContainer,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceVariant,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: displayWidth,
                  height: displayHeight + labelPad,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: displayWidth,
                        height: displayHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: _selectedImage != null
                              ? Image.file(
                                  _selectedImage!,
                                  width: displayWidth,
                                  height: displayHeight,
                                  fit: BoxFit.fill,
                                )
                              : Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.image,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                                ),
                        ),
                      ),
                      if (_selectedImage != null)
                        CustomPaint(
                          size: Size(displayWidth, displayHeight + labelPad),
                          painter: BraillePainter(_detections, sections: _sections,
                              imageHeight: displayHeight),
                        ),
                      if (_isProcessing)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            width: displayWidth,
                            height: displayHeight,
                            child: const BrailleLoadingOverlay(),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (_sections.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.grid_view_rounded,
                                size: 16, color: colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Processing ${_sections.length} section(s)',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              '${_sections.where((s) => s.isDone).length}/${_sections.length}',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: colorScheme.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _sections.isEmpty
                                ? 0
                                : _sections.where((s) => s.isDone).length /
                                    _sections.length,
                            minHeight: 6,
                            backgroundColor: colorScheme.surface,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._sections.map((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: s.isDone
                                        ? Icon(Icons.check_circle,
                                            size: 18,
                                            color: colorScheme.primary)
                                        : (s.index ==
                                                _sections
                                                    .where((x) => x.isDone)
                                                    .length
                                            ? SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: colorScheme.primary,
                                                ),
                                              )
                                            : Icon(Icons.circle_outlined,
                                                size: 18,
                                                color: Colors.grey[400])),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Section ${s.index + 1}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const Spacer(),
                                  Text(
                                    s.isDone
                                        ? '${s.detectionsFound} character${s.detectionsFound == 1 ? '' : 's'}'
                                        : s.index ==
                                                _sections
                                                    .where((x) => x.isDone)
                                                    .length
                                            ? 'scanning...'
                                            : 'waiting',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: s.isDone
                                          ? colorScheme.primary
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _handleImageSelection(_imagePickerHelper.pickImageFromCamera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isProcessing ? null : () => _handleImageSelection(_imagePickerHelper.pickImageFromGallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    if (_selectedImage != null)
                      OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _clear,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 32),

                AnimatedOpacity(
                  opacity: _isProcessing ? 0.5 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Detected Text:',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          if (_processingTime != null) ...[
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.timer_outlined,
                                      size: 14,
                                      color: colorScheme.onPrimaryContainer),
                                  const SizedBox(width: 4),
                                  Text(
                                    _processingTime!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isProcessing
                            ? const Center(child: LinearProgressIndicator())
                            : FadeTransition(
                                opacity: _fadeAnimation,
                                child: _detections.isNotEmpty
                                    ? Text(
                                        _buildReadableText(_detections),
                                        style: theme.textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 2.0,
                                          color: colorScheme.onSurface,
                                        ),
                                      )
                                    : Text(
                                        _statusMessage,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- Dictionary Correction Suggestion ---
                if (_detections.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_fix_high,
                              size: 18, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Correction Suggestion',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                          const Spacer(),
                          if (!_isLoadingCorrection && _correctionSuggestion == null)
                            FilledButton.tonalIcon(
                              onPressed: () async {
                                final raw = _buildReadableText(_detections);
                                setState(() => _isLoadingCorrection = true);
                                final result =
                                    await CorrectionHelper.suggestCorrection(raw);
                                setState(() {
                                  _correctionSuggestion = result;
                                  _isLoadingCorrection = false;
                                });
                              },
                              icon: const Icon(Icons.smart_button_sharp, size: 16),
                              label: const Text('Correct'),
                            ),
                          if (!_isLoadingCorrection && _correctionSuggestion != null)
                            TextButton.icon(
                              onPressed: () {
                                final raw = _buildReadableText(_detections);
                                setState(() {
                                  _correctionSuggestion = null;
                                  _isLoadingCorrection = true;
                                });
                                CorrectionHelper.suggestCorrection(raw).then((r) {
                                  setState(() {
                                    _correctionSuggestion = r;
                                    _isLoadingCorrection = false;
                                  });
                                });
                              },
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Retry'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: colorScheme.primary.withOpacity(0.25)),
                        ),
                        child: _isLoadingCorrection
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('Correcting…',
                                      style: TextStyle(
                                          color: colorScheme.primary)),
                                ],
                              )
                            : _correctionSuggestion != null
                                ? Text(
                                    _correctionSuggestion!,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: colorScheme.onSurface,
                                      height: 1.6,
                                    ),
                                  )
                                : Text(
                                    'Tap "Correct" to fix misspelled or missing words.',
                                    style: TextStyle(color: Colors.grey[500]),
                                  ),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                if (_detections.isNotEmpty)
                  AnimatedOpacity(
                    opacity: _isProcessing ? 0.5 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Character Scores:',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (() {
                                final sorted = List<BrailleDetection>.from(_detections)
                                  ..sort((a, b) {
                                    final dyDiff = a.rect.center.dy.compareTo(b.rect.center.dy);
                                    if (dyDiff.abs() > 0) return dyDiff;
                                    return a.rect.left.compareTo(b.rect.left);
                                  });
                                return sorted.map((detection) {
                                  return Chip(
                                    label: Text(detection.label),
                                    backgroundColor: colorScheme.primaryContainer,
                                    labelStyle: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    avatar: CircleAvatar(
                                      backgroundColor: colorScheme.primary,
                                      child: Text(
                                        '${(detection.score * 100).toInt()}%',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList();
                              })(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LearnBraillePage()),
        ),
        tooltip: 'Learn Braille Alphabet',
        child: const Icon(Icons.menu_book_rounded),
      ),
    );
  }
}

class BraillePainter extends CustomPainter {
  final List<BrailleDetection> detections;
  final List<_SectionStatus> sections;
  final double? imageHeight;

  BraillePainter(this.detections, {this.sections = const [], this.imageHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final double imgH = imageHeight ?? size.height;

    final linePaint = Paint()
      ..color = Colors.deepPurple.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final donePaint = Paint()
      ..color = Colors.green.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    for (final s in sections) {
      final double top    = s.topNorm    * imgH;
      final double bottom = s.bottomNorm * imgH;

      if (s.isDone) {
        canvas.drawRect(Rect.fromLTWH(0, top, size.width, bottom - top), donePaint);
      }

      if (s.index > 0) {
        const double dash = 8, gap = 5;
        double x = 0;
        while (x < size.width) {
          canvas.drawLine(Offset(x, top), Offset((x + dash).clamp(0, size.width), top), linePaint);
          x += dash + gap;
        }
      }

      final label = 'S${s.index + 1}${s.isDone ? " ✓" : ""}';
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: s.isDone ? Colors.green[800] : Colors.deepPurple,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bgRect = Rect.fromLTWH(4, top + 3, tp.width + 8, tp.height + 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bgRect, const Radius.circular(4)),
        Paint()..color = Colors.white.withOpacity(0.8),
      );
      tp.paint(canvas, Offset(8, top + 5));
    }

    for (var detection in detections) {
      final Rect scaledRect = Rect.fromLTWH(
        detection.rect.left * size.width,
        detection.rect.top * imgH,
        detection.rect.width * size.width,
        detection.rect.height * imgH,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          text: detection.label,
          style: const TextStyle(
            color: Colors.deepPurple,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final double labelX = scaledRect.center.dx - textPainter.width / 2;
      final double labelY = scaledRect.bottom + 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(labelX - 3, labelY, textPainter.width + 6, textPainter.height + 2),
          const Radius.circular(4),
        ),
        Paint()..color = Colors.white.withOpacity(0.85),
      );

      textPainter.paint(canvas, Offset(labelX, labelY + 1));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BrailleLoadingOverlay extends StatefulWidget {
  const BrailleLoadingOverlay({super.key});

  @override
  State<BrailleLoadingOverlay> createState() => _BrailleLoadingOverlayState();
}

class _BrailleLoadingOverlayState extends State<BrailleLoadingOverlay>
    with TickerProviderStateMixin {

  static const Map<String, List<int>> _patterns = {
    'A': [1],         'B': [1,2],       'C': [1,4],     'D': [1,4,5],
    'E': [1,5],       'F': [1,2,4],     'G': [1,2,4,5], 'H': [1,2,5],
    'I': [2,4],       'J': [2,4,5],     'K': [1,3],     'L': [1,2,3],
    'M': [1,3,4],     'N': [1,3,4,5],   'O': [1,3,5],   'P': [1,2,3,4],
    'Q': [1,2,3,4,5], 'R': [1,2,3,5],   'S': [2,3,4],   'T': [2,3,4,5],
    'U': [1,3,6],     'V': [1,2,3,6],   'W': [2,4,5,6], 'X': [1,3,4,6],
    'Y': [1,3,4,5,6], 'Z': [1,3,5,6],
  };

  final List<String> _letters = _patterns.keys.toList();
  int _currentIndex = 0;
  late Timer _timer;
  late AnimationController _dotController;   
  late AnimationController _slideController;
  late AnimationController _colorController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));

    _dotController.forward();

    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) async {
      await _slideController.forward();
      if (!mounted) return;
      setState(() => _currentIndex = (_currentIndex + 1) % _letters.length);
      _dotController.reset();
      _slideController.reset();
      _dotController.forward();
    });
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.4, end: 0.7).animate(
      CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _dotController.dispose();
    _slideController.dispose();
    _colorController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String letter = _letters[_currentIndex];
    final List<int> activeDots = _patterns[letter]!;

    return AnimatedBuilder(
        animation: _opacityAnimation,
        builder: (_, __) {
          return
      Container(
        color: Colors.black.withOpacity(_opacityAnimation.value),
      child: LayoutBuilder(
        builder: (context, constraints) => FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 28),

                const Text(
            'Analysing image…',
            style: TextStyle(color: Colors.white, fontSize: 24,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 28),

          AnimatedBuilder(
            animation: _dotController,
            builder: (_, __) => _BrailleCell(
              activeDots: activeDots,
              progress: _dotController.value,
            ),
          ),

          const SizedBox(height: 20),

          AnimatedBuilder(
            animation: _slideController,
            builder: (_, child) => FadeTransition(
              opacity: Tween(begin: 1.0, end: 0.0).animate(_slideController),
              child: Transform.translate(
                offset: Offset(0, -12 * _slideController.value),
                child: child,
              ),
            ),
            child: Text(
              letter,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ),

          const SizedBox(height: 6),
          Text(
            'Dots: ${activeDots.join('  ')}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          const SizedBox(height: 28),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == (_currentIndex % 3) ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == (_currentIndex % 3)
                      ? Colors.deepPurple[200]
                      : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
          ),
        ),
      ),
    );});
  }
}

class _BrailleCell extends StatelessWidget {
  final List<int> activeDots;
  final double progress; 

  const _BrailleCell({required this.activeDots, required this.progress});

  @override
  Widget build(BuildContext context) {
    const double dotSize = 18;
    const double dotSpacingV = 10;
    const double dotSpacingH = 22;

    Widget dot(int dotNumber, int orderInActive) {
      final bool isActive = activeDots.contains(dotNumber);
      final double threshold = isActive && activeDots.isNotEmpty
          ? orderInActive / activeDots.length
          : 1.0;
      final double scale = isActive && progress >= threshold
          ? 1.0
          : 0.3;
      final Color color = isActive && progress >= threshold
          ? Colors.deepPurple[200]!
          : Colors.white12;

      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: dotSize,
        height: dotSize,
        margin: const EdgeInsets.symmetric(vertical: dotSpacingV / 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: isActive && progress >= threshold
              ? [BoxShadow(
                  color: Colors.deepPurple.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 1,
                )]
              : [],
        ),
        transform: Matrix4.identity()
          ..translate(dotSize / 2, dotSize / 2)
          ..scale(scale)
          ..translate(-dotSize / 2, -dotSize / 2),
      );
    }

    int orderOf(int d) => activeDots.indexOf(d);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(children: [dot(1, orderOf(1)), dot(2, orderOf(2)), dot(3, orderOf(3))]),
        SizedBox(width: dotSpacingH),
        Column(children: [dot(4, orderOf(4)), dot(5, orderOf(5)), dot(6, orderOf(6))]),
      ],
    );
  }
}

class _SectionStatus {
  final int index;
  final int total;
  final double topNorm;
  final double bottomNorm;
  final int detectionsFound;
  final bool isDone;

  const _SectionStatus({
    required this.index,
    required this.total,
    this.topNorm = 0,
    this.bottomNorm = 0,
    this.detectionsFound = 0,
    this.isDone = false,
  });
}