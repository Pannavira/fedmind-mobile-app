# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# ONNX Runtime Android JNI (Critical: Prevents R8 from stripping JNI bridge and reflection)
-keep class ai.onnxruntime.** { *; }
-keep interface ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# flutter_onnxruntime plugin classes
-keep class com.masicai.flutteronnxruntime.** { *; }
-dontwarn com.masicai.flutteronnxruntime.**

# Application native classes
-keep class com.fedmind.fedmind_mobile_app.** { *; }
-dontwarn com.fedmind.fedmind_mobile_app.**
