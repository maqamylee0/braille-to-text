// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'image_picker_helper.dart';
// import 'tflite_helper.dart';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Braille Translator',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true,
//       ),
//       home: const BrailleTranslatorHome(),
//     );
//   }
// }
//
// class BrailleTranslatorHome extends StatefulWidget {
//   const BrailleTranslatorHome({super.key});
//
//   @override
//   State<BrailleTranslatorHome> createState() => _BrailleTranslatorHomeState();
// }
//
// class _BrailleTranslatorHomeState extends State<BrailleTranslatorHome> {
//   final ImagePickerHelper _imagePickerHelper = ImagePickerHelper();
//   final TfliteHelper _tfliteHelper = TfliteHelper();
//
//   File? _selectedImage;
//   List<BrailleDetection> _detections = [];
//   bool _isProcessing = false;
//   String _statusMessage = "Upload or take a photo of braille to translate.";
//
//   @override
//   void initState() {
//     super.initState();
//     _initModel();
//   }
//
//   Future<void> _initModel() async {
//     await _tfliteHelper.loadModel();
//   }
//
//   @override
//   void dispose() {
//     _tfliteHelper.close();
//     super.dispose();
//   }
//
//   Future<void> _handleImageSelection(Future<File?> Function() pickMethod) async {
//     final file = await pickMethod();
//     if (file != null) {
//       setState(() {
//         _selectedImage = file;
//         _isProcessing = true;
//         _detections = []; // Clear old results
//         _statusMessage = "Processing image...";
//       });
//
//       // Run inference - returns a list of detection objects
//       final results = await _tfliteHelper.processImage(file);
//
//       setState(() {
//         _detections = results;
//         _isProcessing = false;
//         _statusMessage = results.isEmpty
//             ? "No Braille characters detected."
//             : "Translation complete.";
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // Define a fixed size for the display area to ensure the painter aligns correctly
//     const double displaySize = 350.0;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Braille Translator'),
//         centerTitle: true,
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               // --- Image & Annotation Area ---
//               Center(
//                 child: Container(
//                   width: displaySize,
//                   height: displaySize,
//                   decoration: BoxDecoration(
//                     color: Colors.grey[200],
//                     borderRadius: BorderRadius.circular(12),
//                     border: Border.all(color: Colors.grey[400]!),
//                   ),
//                   child: _selectedImage != null
//                       ? Stack(
//                     children: [
//                       // 1. The Actual Image
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(12),
//                         child: Image.file(
//                           _selectedImage!,
//                           width: displaySize,
//                           height: displaySize,
//                           fit: BoxFit.fill, // Ensures scale matches painter
//                         ),
//                       ),
//                       // 2. The Annotation Layer
//                       CustomPaint(
//                         size: const Size(displaySize, displaySize),
//                         painter: BraillePainter(_detections),
//                       ),
//                     ],
//                   )
//                       : const Center(
//                     child: Icon(Icons.image, size: 80, color: Colors.grey),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 24),
//
//               // --- Action Buttons ---
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   ElevatedButton.icon(
//                     onPressed: _isProcessing
//                         ? null
//                         : () => _handleImageSelection(_imagePickerHelper.pickImageFromCamera),
//                     icon: const Icon(Icons.camera_alt),
//                     label: const Text('Camera'),
//                   ),
//                   ElevatedButton.icon(
//                     onPressed: _isProcessing
//                         ? null
//                         : () => _handleImageSelection(_imagePickerHelper.pickImageFromGallery),
//                     icon: const Icon(Icons.photo_library),
//                     label: const Text('Gallery'),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 32),
//
//               // --- Results Area ---
//               Text(
//                 _isProcessing ? 'Status: Processing...' : 'Detected Text:',
//                 style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 8),
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.deepPurple[50],
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: _isProcessing
//                     ? const Center(child: LinearProgressIndicator())
//                     : Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     if (_detections.isNotEmpty)
//                       Text(
//                         _detections.map((e) => e.label).join(" "),
//                         style: const TextStyle(
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                             letterSpacing: 2.0,
//                             color: Colors.deepPurple
//                         ),
//                       )
//                     else
//                       Text(
//                         _statusMessage,
//                         style: const TextStyle(fontSize: 16, color: Colors.grey),
//                       ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // --- The Custom Painter to draw the red boxes ---
// class BraillePainter extends CustomPainter {
//   final List<BrailleDetection> detections;
//
//   BraillePainter(this.detections);
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final boxPaint = Paint()
//       ..color = Colors.redAccent
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2.0;
//
//     for (var detection in detections) {
//       // FIX: Use 1.0 instead of 640 if your model returns normalized values (0.0 to 1.0)
//       // Most YOLOv8 TFLite exports use normalized coordinates.
//       final double scaleX = size.width / 1.0;
//       final double scaleY = size.height / 1.0;
//
//       final Rect scaledRect = Rect.fromLTWH(
//         detection.rect.left * scaleX,
//         detection.rect.top * scaleY,
//         detection.rect.width * scaleX,
//         detection.rect.height * scaleY,
//       );
//
//       // Draw the bounding box
//       canvas.drawRRect(
//           RRect.fromRectAndRadius(scaledRect, const Radius.circular(4)),
//           boxPaint
//       );
//
//       // Draw the Label background and text
//       final textPainter = TextPainter(
//         text: TextSpan(
//           text: detection.label,
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 12,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         textDirection: TextDirection.ltr,
//       )..layout();
//
//       final backgroundPaint = Paint()..color = Colors.redAccent;
//       canvas.drawRect(
//           Rect.fromLTWH(
//               scaledRect.left,
//               scaledRect.top - textPainter.height,
//               textPainter.width + 4,
//               textPainter.height
//           ),
//           backgroundPaint
//       );
//
//       textPainter.paint(canvas, Offset(scaledRect.left + 2, scaledRect.top - textPainter.height));
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }

// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/scheduler.dart';
// import 'image_picker_helper.dart';
// import 'tflite_helper.dart';
//
// void main() {
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Braille Translator',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: Colors.deepPurple,
//           brightness: Brightness.light,
//         ),
//         useMaterial3: true,
//         fontFamily: 'Poppins', // Make sure to add this font or remove line
//       ),
//       home: const BrailleTranslatorHome(),
//     );
//   }
// }
//
// class BrailleTranslatorHome extends StatefulWidget {
//   const BrailleTranslatorHome({super.key});
//
//   @override
//   State<BrailleTranslatorHome> createState() => _BrailleTranslatorHomeState();
// }
//
// class _BrailleTranslatorHomeState extends State<BrailleTranslatorHome>
//     with SingleTickerProviderStateMixin {
//   final ImagePickerHelper _imagePickerHelper = ImagePickerHelper();
//   final TfliteHelper _tfliteHelper = TfliteHelper();
//
//   File? _selectedImage;
//   List<BrailleDetection> _detections = [];
//   bool _isProcessing = false;
//   String _statusMessage = "Upload or take a photo of braille to translate.";
//
//   // Animation controllers
//   late AnimationController _fadeController;
//   late Animation<double> _fadeAnimation;
//
//   // Model input size (must match your model)
//   static const int _modelInputSize = 640;
//   // Display size for the image preview
//   static const double _displaySize = 350.0;
//
//   @override
//   void initState() {
//     super.initState();
//     _initModel();
//
//     _fadeController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 500),
//     );
//     _fadeAnimation = CurvedAnimation(
//       parent: _fadeController,
//       curve: Curves.easeInOut,
//     );
//   }
//
//   Future<void> _initModel() async {
//     await _tfliteHelper.loadModel();
//   }
//
//   @override
//   void dispose() {
//     _tfliteHelper.close();
//     _fadeController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _handleImageSelection(Future<File?> Function() pickMethod) async {
//     final file = await pickMethod();
//     if (file != null) {
//       setState(() {
//         _selectedImage = file;
//         _isProcessing = true;
//         _detections = [];
//         _statusMessage = "Processing image...";
//       });
//       _fadeController.reset();
//
//       final results = await _tfliteHelper.processImage(file);
//
//       setState(() {
//         _detections = results;
//         _isProcessing = false;
//         _statusMessage = results.isEmpty
//             ? "No Braille characters detected."
//             : "Translation complete.";
//         _fadeController.forward();
//       });
//     }
//   }
//
//   void _clear() {
//     setState(() {
//       _selectedImage = null;
//       _detections = [];
//       _statusMessage = "Upload or take a photo of braille to translate.";
//       _fadeController.reset();
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         title: const Text('Braille Translator'),
//         centerTitle: true,
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//         foregroundColor: colorScheme.onPrimaryContainer,
//         flexibleSpace: Container(
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [colorScheme.primary, colorScheme.secondary],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//       ),
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               colorScheme.surface,
//               colorScheme.surfaceVariant,
//             ],
//           ),
//         ),
//         child: SafeArea(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.stretch,
//               children: [
//                 // --- Image & Annotation Area ---
//                 Center(
//                   child: Stack(
//                     children: [
//                       Container(
//                         width: _displaySize,
//                         height: _displaySize,
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(20),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.1),
//                               blurRadius: 10,
//                               offset: const Offset(0, 4),
//                             ),
//                           ],
//                         ),
//                         child: ClipRRect(
//                           borderRadius: BorderRadius.circular(20),
//                           child: _selectedImage != null
//                               ? Image.file(
//                             _selectedImage!,
//                             width: _displaySize,
//                             height: _displaySize,
//                             fit: BoxFit.fill,
//                           )
//                               : Container(
//                             color: Colors.grey[200],
//                             child: const Icon(
//                               Icons.image,
//                               size: 80,
//                               color: Colors.grey,
//                             ),
//                           ),
//                         ),
//                       ),
//                       if (_selectedImage != null)
//                         CustomPaint(
//                           size: const Size(_displaySize, _displaySize),
//                           painter: BraillePainter(
//                             _detections,
//                             modelInputSize: _modelInputSize,
//                             displaySize: _displaySize,
//                           ),
//                         ),
//                       if (_isProcessing)
//                         Container(
//                           width: _displaySize,
//                           height: _displaySize,
//                           decoration: BoxDecoration(
//                             borderRadius: BorderRadius.circular(20),
//                             color: Colors.black54,
//                           ),
//                           child: const Center(
//                             child: CircularProgressIndicator(
//                               color: Colors.white,
//                             ),
//                           ),
//                         ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(height: 24),
//
//                 // --- Action Buttons ---
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     ElevatedButton.icon(
//                       onPressed: _isProcessing ? null : () => _handleImageSelection(_imagePickerHelper.pickImageFromCamera),
//                       icon: const Icon(Icons.camera_alt),
//                       label: const Text('Camera'),
//                       style: ElevatedButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(30),
//                         ),
//                       ),
//                     ),
//                     ElevatedButton.icon(
//                       onPressed: _isProcessing ? null : () => _handleImageSelection(_imagePickerHelper.pickImageFromGallery),
//                       icon: const Icon(Icons.photo_library),
//                       label: const Text('Gallery'),
//                       style: ElevatedButton.styleFrom(
//                         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(30),
//                         ),
//                       ),
//                     ),
//                     if (_selectedImage != null)
//                       OutlinedButton.icon(
//                         onPressed: _isProcessing ? null : _clear,
//                         icon: const Icon(Icons.clear),
//                         label: const Text('Clear'),
//                         style: OutlinedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(30),
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//                 const SizedBox(height: 32),
//
//                 // --- Results Area ---
//                 AnimatedOpacity(
//                   opacity: _isProcessing ? 0.5 : 1.0,
//                   duration: const Duration(milliseconds: 300),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'Detected Text:',
//                         style: theme.textTheme.titleLarge?.copyWith(
//                           fontWeight: FontWeight.bold,
//                           color: colorScheme.primary,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Container(
//                         padding: const EdgeInsets.all(16),
//                         decoration: BoxDecoration(
//                           color: colorScheme.surfaceVariant,
//                           borderRadius: BorderRadius.circular(16),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withOpacity(0.05),
//                               blurRadius: 4,
//                               offset: const Offset(0, 2),
//                             ),
//                           ],
//                         ),
//                         child: _isProcessing
//                             ? const ShimmerLoader()
//                             : FadeTransition(
//                           opacity: _fadeAnimation,
//                           child: _detections.isNotEmpty
//                               ? Text(
//                             _detections.map((e) => e.label).join(" "),
//                             style: TextStyle(
//                               fontSize: 28,
//                               fontWeight: FontWeight.bold,
//                               letterSpacing: 2.0,
//                               color: colorScheme.primary,
//                               height: 1.2,
//                             ),
//                           )
//                               : Text(
//                             _statusMessage,
//                             style: TextStyle(
//                               fontSize: 16,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//       floatingActionButton: _selectedImage == null
//           ? FloatingActionButton.extended(
//         onPressed: () => _handleImageSelection(_imagePickerHelper.pickImageFromCamera),
//         icon: const Icon(Icons.camera_alt),
//         label: const Text('Take Photo'),
//         elevation: 4,
//       )
//           : null,
//     );
//   }
// }
//
// // --- The Enhanced Custom Painter with Correct Scaling ---
// class BraillePainter extends CustomPainter {
//   final List<BrailleDetection> detections;
//   final int modelInputSize;
//   final double displaySize;
//
//   BraillePainter(
//       this.detections, {
//         required this.modelInputSize,
//         required this.displaySize,
//       });
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     final scaleFactor = displaySize / modelInputSize;
//
//     for (var detection in detections) {
//       // Scale coordinates from model input space (0..modelInputSize) to display space
//       final left = detection.rect.left * scaleFactor;
//       final top = detection.rect.top * scaleFactor;
//       final width = detection.rect.width * scaleFactor;
//       final height = detection.rect.height * scaleFactor;
//
//       final scaledRect = Rect.fromLTWH(left, top, width, height);
//
//       // Draw rounded bounding box
//       final boxPaint = Paint()
//         ..color = Colors.redAccent
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 2.0;
//       canvas.drawRRect(
//         RRect.fromRectAndRadius(scaledRect, const Radius.circular(6)),
//         boxPaint,
//       );
//
//       // Label background (semi-transparent)
//       final textSpan = TextSpan(
//         text: detection.label,
//         style: const TextStyle(
//           color: Colors.white,
//           fontSize: 12,
//           fontWeight: FontWeight.bold,
//         ),
//       );
//       final textPainter = TextPainter(
//         text: textSpan,
//         textDirection: TextDirection.ltr,
//       )..layout();
//
//       final labelX = scaledRect.left;
//       final labelY = scaledRect.top - textPainter.height - 4;
//       final labelBackground = Rect.fromLTWH(
//         labelX,
//         labelY,
//         textPainter.width + 8,
//         textPainter.height + 4,
//       );
//
//       final bgPaint = Paint()..color = Colors.redAccent.withOpacity(0.8);
//       canvas.drawRRect(
//         RRect.fromRectAndRadius(labelBackground, const Radius.circular(4)),
//         bgPaint,
//       );
//
//       textPainter.paint(
//         canvas,
//         Offset(labelX + 4, labelY + 2),
//       );
//     }
//   }
//
//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }
//
// // --- Shimmer Effect for Loading State ---
// class ShimmerLoader extends StatefulWidget {
//   const ShimmerLoader({super.key});
//
//   @override
//   State<ShimmerLoader> createState() => _ShimmerLoaderState();
// }
//
// class _ShimmerLoaderState extends State<ShimmerLoader>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//
//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1200),
//     )..repeat();
//   }
//
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _controller,
//       builder: (context, child) {
//         return Container(
//           height: 40,
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: [
//                 Colors.grey[300]!,
//                 Colors.grey[100]!,
//                 Colors.grey[300]!,
//               ],
//               stops: [0.0, 0.5, 1.0],
//               begin: Alignment(-1.0 + _controller.value * 2, 0),
//               end: Alignment(1.0 - _controller.value * 2, 0),
//             ),
//             borderRadius: BorderRadius.circular(8),
//           ),
//         );
//       },
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'splash_screen.dart'; // Import the new splash screen

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(), // Start with splash screen
    );
  }
}

