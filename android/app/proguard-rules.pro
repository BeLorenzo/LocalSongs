# ExoPlayer & Media3 rules for just_audio
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# just_audio & audio_service
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audioservice.** { *; }
-dontwarn com.ryanheise.**
