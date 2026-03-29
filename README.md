# Braille OCR — Android App

A mobile application that detects and translates braille characters from photos using an on-device YOLOv8 model. Point your phone camera at a braille page and the app returns the Latin text — no internet connection required for detection.

---

## How it works

1. The user takes a photo or selects one from the gallery
2. The image is split into horizontal strips with 15% overlap so no character falls on a boundary
3. Each strip is letterbox-resized to 320×320 and fed to a YOLOv8n TFLite model running entirely on-device
4. Detected characters are sorted left-to-right and top-to-bottom into words and lines
5. A spell-correction step using Levenshtein distance against an English dictionary cleans up misdetections
6. The final text is displayed with an optional Gemini AI suggestion for context-level correction

**Primary metric:** Character Error Rate (CER) — target ≤ 10%

---

## Repository structure

```
braille/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── BrailleTranslationHome.dart  # Main screen
│   ├── tflite_helper.dart           # Model inference + post-processing
│   ├── correction_helper.dart       # Levenshtein spell correction
│   ├── llm_helper.dart              # Gemini API fallback correction
│   ├── image_picker_helper.dart     # Camera / gallery input
│   ├── learn_braille.dart           # Braille learning screen
│   └── splash_screen.dart          # Splash screen
├── assets/
│   ├── best_3_float16.tflite        # YOLOv8n model (float16, 320×320 input)
│   ├── best_4_float16.tflite        # Alternative model weights
│   ├── english.txt                  # Dictionary for spell correction
│   └── launcher.png                 # App icon
├── braile-to-text.ipynb             # Training + evaluation notebook (Colab)
└── pubspec.yaml
```

---

## Part 1 — Running the training notebook (Google Colab)

### Prerequisites

- A Google account with access to [Google Colab](https://colab.research.google.com)
- A [Roboflow](https://roboflow.com) account and API key
- The **AngelinaDataset** folder (braille annotation dataset — upload separately)
- A Colab session with GPU runtime (Runtime → Change runtime type → T4 GPU)

### Step 1 — Add your Roboflow API key

1. Open the notebook in Colab
2. Click the **key icon** (Secrets) in the left sidebar
3. Add a secret named `ROBOFLOW_API_KEY` with your Roboflow API key as the value
4. Toggle on notebook access for that secret

### Step 2 — Upload the AngelinaDataset

In the Colab Files panel (folder icon, left sidebar), upload your `AngelinaDataset` folder to `/content/AngelinaDataset`.

Alternatively mount Google Drive:
```python
from google.colab import drive
drive.mount('/content/drive')
# then copy:
# !cp -r /content/drive/MyDrive/AngelinaDataset /content/
```

### Step 3 — Run the notebook cells in order

| Cell | What it does |
|------|-------------|
| 1 | Installs dependencies (`roboflow`, `ultralytics`, `supervision`) |
| 2 | Downloads 7 braille datasets from Roboflow |
| 3 | Inventory check on downloaded images |
| 4 | Converts Angelina dataset annotations to YOLO format |
| 5 | Merges all datasets with a stratified 70/15/15 split |
| 6 | Creates `data.yaml` |
| 7 | **Trains YOLOv8n** — 640×640 input, 50 epochs (100 recommended) |
| 8 | Saves best weights to `/content/saved_models/` |
| 9 | Copies training results and plots |
| 10 | Lists all output file paths |
| 11 | Verifies class labels are consistent across datasets |
| 12 | Evaluates model on the validation set (mAP, precision, recall) |
| 13–19 | **Performance visualisations** — loss curves, confusion matrix, PR/F1 curves, per-class AP |
| 20 | Runs the full braille-to-text pipeline on a sample test image |
| 21–22 | **CER evaluation** — computes Character Error Rate across the full test set with distribution plots, cumulative curve, and pass/fail breakdown |
| 23 | Exports the model to **TFLite float16 at 320×320** for Android |

### Training configuration

```
Model        : YOLOv8n (nano)
imgsz        : 640 (training)  →  320 (TFLite export)
epochs       : 50  (100 for best results)
batch        : 16
classes      : 26  (A–Z)
augmentation : rotation ±5°, brightness variation, mosaic=1.0
flipud/fliplr: disabled  (braille is direction-sensitive)
early stop   : patience=10
```

### Outputs

All outputs are saved to `/content/saved_models/`:

| File | Description |
|------|-------------|
| `braille_best.pt` | PyTorch weights |
| `best_saved_model/best_float16.tflite` | TFLite model for Android |
| `loss_curves.png` | Training vs validation loss (box, class, DFL) |
| `metric_curves.png` | Precision, recall, mAP over epochs |
| `confusion_matrix_display.png` | Normalised confusion matrix |
| `pr_f1_curves.png` | PR curve and F1 curve |
| `summary_bar_chart.png` | Final precision / recall / mAP bar chart |
| `per_class_ap.png` | AP@0.5 per letter (A–Z) |
| `cer_visualisations.png` | Full CER evaluation plots |

Download the `.tflite` file and place it in `assets/` to update the app model.

---

## Part 2 — Running the Flutter app

### Requirements

| Tool | Version |
|------|---------|
| Flutter | 3.41.4 or later |
| Dart | 3.11.3 or later |
| Android compileSdk | 36 |
| Android targetSdk | 34 |
| Android NDK | 28.2.13676358 |
| Android Studio / VS Code | Any recent version |

### Step 1 — Install Flutter

Follow the official guide at https://docs.flutter.dev/get-started/install

Verify your setup:
```bash
flutter doctor
```
All required items should show a green tick. Android toolchain and a connected device or emulator are required.

### Step 2 — Install Android NDK

In Android Studio go to **SDK Manager → SDK Tools → NDK (Side by side)** and install version `28.2.13676358`.

Or via command line:
```bash
sdkmanager "ndk;28.2.13676358"
```

### Step 3 — Clone and set up

```bash
git clone <your-repo-url>
cd braille
flutter clean
flutter pub get
```

> `flutter clean` is important — it clears the Gradle build cache and ensures the correct plugin versions are used rather than stale cached ones.

### Step 4 — Connect a device

Plug in an Android device with **USB debugging enabled** (Developer Options), or start an Android emulator (API 21+).

```bash
flutter devices   # verify your device appears
```

### Step 5 — Run

```bash
flutter run
```

For a release APK:
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Updating the TFLite model

To swap in a newly trained model:
1. Copy your `best_float16.tflite` into `assets/`
2. Update the filename in [lib/tflite_helper.dart](lib/tflite_helper.dart) line 35:
   ```dart
   _interpreter = await Interpreter.fromAsset('assets/your_new_model.tflite');
   ```
3. Re-run `flutter clean && flutter run`

### Known build issue (already fixed)

If you see a `PluginRegistry.Registrar` compile error, it means the Gradle cache has stale old plugin versions. Fix with:
```bash
flutter clean
flutter pub get
flutter run
```
This is already handled in `pubspec.yaml` via a `dependency_overrides` entry for `flutter_plugin_android_lifecycle`.

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `tflite_flutter` | ^0.12.1 | Runs the YOLOv8 TFLite model on-device |
| `image_picker` | ^1.1.0 | Camera and gallery access |
| `image` | ^4.2.0 | Image decoding and letterbox preprocessing |
| `http` | ^1.2.0 | Gemini API calls for LLM-based correction |
| `cupertino_icons` | ^1.0.6 | iOS-style icons |
