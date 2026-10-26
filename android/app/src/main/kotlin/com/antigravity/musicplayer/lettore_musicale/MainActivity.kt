package com.antigravity.musicplayer.lettore_musicale

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.audiofx.AudioEffect
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.antigravity.localsongs/system_equalizer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "openEqualizer") {
                val sessionId = call.argument<Int>("sessionId") ?: 0
                
                // Notifica ai motori DSP/equalizzatori in background l'apertura della sessione audio
                if (sessionId != 0) {
                    val sessionIntent = Intent(AudioEffect.ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION).apply {
                        putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
                        putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                        putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
                    }
                    sendBroadcast(sessionIntent)
                }

                // Tenta prima di aprire il pannello equalizzatore dedicato di sistema / app (MusicFX, Dolby, Wavelet, ecc.)
                val panelIntent = Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL).apply {
                    if (sessionId != 0) {
                        putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
                    }
                    putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                    putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }

                try {
                    startActivity(panelIntent)
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    // Fallback per Pixel / AOSP che non hanno MusicFX di serie: apri le impostazioni audio di sistema
                    try {
                        val soundSettingsIntent = Intent(Settings.ACTION_SOUND_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(soundSettingsIntent)
                        result.success(true)
                    } catch (fallbackEx: Exception) {
                        result.success(false)
                    }
                } catch (e: Exception) {
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
