# Agent Pro Ghana ProGuard Rules

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**

# Security: ensure sensitive class names are not removed
-keep class com.agentpro.ghana.** { *; }

# Keep USSD and telephony classes
-keep class android.telephony.** { *; }
-keep class android.telecom.** { *; }

# OkHttp (used by Dio)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
