# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# TFLite
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Play Core (referenced by Flutter engine but not used in non-Play-Store builds)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
