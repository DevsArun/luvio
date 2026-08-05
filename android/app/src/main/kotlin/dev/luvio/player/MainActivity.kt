package dev.luvio.player

import android.os.Environment
import android.os.StatFs
import android.provider.Settings
import android.view.WindowManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hosts the Flutter engine and exposes storage-volume discovery over a
 * MethodChannel so the Dart side can list internal storage and SD cards
 * (common on Amazon Fire tablets).
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "luvio_player/storage"
        private const val MEDIA_CHANNEL = "luvio_player/media_notification"
        private const val SCREEN_CHANNEL = "luvio_player/screen"
    }

    private var mediaChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getVolumes" -> result.success(getVolumes())

                // MediaStore-backed library scan. This is the reliable way to
                // find videos on Android 11+ / Fire OS 8, where walking the
                // filesystem with the File API returns nothing.
                "getVideos" -> result.success(MediaStoreBridge.queryVideos(this))
                "getAudio" -> result.success(MediaStoreBridge.queryAudio(this))

                "hasAllFilesAccess" ->
                    result.success(MediaStoreBridge.hasAllFilesAccess())
                "requestAllFilesAccess" ->
                    result.success(MediaStoreBridge.requestAllFilesAccess(this))

                "deleteFile" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrEmpty()) {
                        result.success(false)
                    } else {
                        result.success(MediaStoreBridge.deleteFile(this, path))
                    }
                }

                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (!path.isNullOrEmpty()) {
                        MediaStoreBridge.scanFile(this, path)
                    }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        val media = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_CHANNEL
        )
        mediaChannel = media
        media.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    try {
                        MediaNotificationService.update(
                            this,
                            call.argument<String>("title") ?: "Luvio Player",
                            call.argument<String>("subtitle") ?: "",
                            call.argument<Boolean>("playing") ?: false,
                            (call.argument<Number>("position")?.toLong()) ?: 0L,
                            (call.argument<Number>("duration")?.toLong()) ?: 0L,
                            call.argument<Boolean>("hasNext") ?: false,
                            call.argument<Boolean>("hasPrevious") ?: false
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        // Never let notification problems break playback.
                        result.success(false)
                    }
                }
                "hide" -> {
                    try {
                        MediaNotificationService.stop(this)
                    } catch (_: Exception) {
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Window brightness. The screen_brightness plugin does not work on
        // every Fire OS / Android build, so we drive the window attribute
        // ourselves - this is the same mechanism MX Player uses and needs no
        // runtime permission because it only affects our own window.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBrightness" -> result.success(currentBrightness())
                "setBrightness" -> {
                    val value = (call.argument<Double>("value") ?: -1.0)
                    result.success(applyBrightness(value.toFloat()))
                }
                "resetBrightness" -> {
                    // BRIGHTNESS_OVERRIDE_NONE = -1f hands control back to the
                    // system slider when the player closes.
                    result.success(applyBrightness(-1f))
                }
                else -> result.notImplemented()
            }
        }

        // Route notification / lockscreen button presses back into Dart.
        MediaNotificationService.actionListener = { action ->
            runOnUiThread {
                mediaChannel?.invokeMethod("action", action)
            }
        }
    }

    /// Returns the window brightness, falling back to the system-wide value
    /// the first time (before we have overridden anything).
    private fun currentBrightness(): Double {
        val windowValue = window?.attributes?.screenBrightness ?: -1f
        if (windowValue >= 0f) return windowValue.toDouble()
        return try {
            val system = Settings.System.getInt(
                contentResolver,
                Settings.System.SCREEN_BRIGHTNESS
            )
            (system / 255.0).coerceIn(0.0, 1.0)
        } catch (_: Exception) {
            0.5
        }
    }

    private fun applyBrightness(value: Float): Boolean {
        return try {
            val win = window ?: return false
            val params: WindowManager.LayoutParams = win.attributes
            params.screenBrightness =
                if (value < 0f) -1f else value.coerceIn(0.01f, 1.0f)
            runOnUiThread { win.attributes = params }
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onDestroy() {
        MediaNotificationService.actionListener = null
        mediaChannel = null
        super.onDestroy()
    }

    private fun getVolumes(): List<HashMap<String, Any>> {
        val volumes = ArrayList<HashMap<String, Any>>()

        // Internal shared storage.
        try {
            val internal = Environment.getExternalStorageDirectory()
            if (internal != null && internal.exists()) {
                volumes.add(volumeInfo(internal, "Internal Storage", removable = false))
            }
        } catch (_: Exception) {
            // Ignore and continue with removable volumes.
        }

        // Removable volumes (SD cards). App-specific dirs live under
        // <mount>/Android/data/<package>/files — walk up to the mount root.
        try {
            val internalPath = Environment.getExternalStorageDirectory()?.absolutePath
            val dirs = ContextCompat.getExternalFilesDirs(this, null)
            for (dir in dirs) {
                if (dir == null) continue
                var root: File = dir
                var hops = 0
                while (hops < 5 && root.parentFile != null &&
                    root.absolutePath.contains("/Android")
                ) {
                    root = root.parentFile!!
                    if (!root.absolutePath.contains("/Android")) break
                    hops++
                }
                val path = root.absolutePath
                if (internalPath != null && path.startsWith(internalPath)) continue
                if (volumes.any { it["path"] == path }) continue
                if (!root.exists()) continue
                volumes.add(volumeInfo(root, "SD Card", removable = true))
            }
        } catch (_: Exception) {
            // SD card discovery is best-effort.
        }

        return volumes
    }

    private fun volumeInfo(
        root: File,
        name: String,
        removable: Boolean
    ): HashMap<String, Any> {
        var total = 0L
        var free = 0L
        try {
            val stat = StatFs(root.absolutePath)
            total = stat.totalBytes
            free = stat.availableBytes
        } catch (_: Exception) {
            // Leave zeros if the volume can't be statted.
        }
        return hashMapOf(
            "path" to root.absolutePath,
            "name" to name,
            "removable" to removable,
            "total" to total,
            "free" to free
        )
    }
}
