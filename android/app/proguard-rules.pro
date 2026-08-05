# Flutter engine
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# media_kit native bindings
-keep class com.alexmercerind.** { *; }
-dontwarn com.alexmercerind.**
-keep class mediakitandroidhelper.** { *; }
-dontwarn mediakitandroidhelper.**

# App classes (MethodChannel host)
-keep class dev.luvio.player.** { *; }
