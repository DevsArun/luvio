package dev.luvio.player

import android.app.Activity
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import java.io.File

/**
 * Bridges Android's MediaStore into Dart.
 *
 * Why this exists:
 * On Android 11+ (Fire OS 8 too) an app can no longer freely walk
 * /storage/emulated/0 with the plain File API. `Directory.list()` silently
 * returns nothing for most folders, which is exactly why the library scan
 * came back empty even though videos were clearly on the device.
 *
 * MediaStore is the supported way to enumerate media. It works with only the
 * READ_MEDIA_VIDEO / READ_EXTERNAL_STORAGE grant, needs no "All files access",
 * and returns every video the system has indexed.
 */
object MediaStoreBridge {

    /** True when the user granted "All files access" (Android 11+). */
    fun hasAllFilesAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
    }

    /** Opens the system "All files access" screen for this app. */
    fun requestAllFilesAccess(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return try {
            val intent = Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:" + activity.packageName)
            )
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            try {
                activity.startActivity(
                    Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                )
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    /** Every video MediaStore knows about, newest first. */
    fun queryVideos(context: Context): List<HashMap<String, Any>> {
        val out = ArrayList<HashMap<String, Any>>()
        val projection = arrayOf(
            MediaStore.Video.Media._ID,
            MediaStore.Video.Media.DATA,
            MediaStore.Video.Media.SIZE,
            MediaStore.Video.Media.DATE_MODIFIED,
            MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.WIDTH,
            MediaStore.Video.Media.HEIGHT,
            MediaStore.Video.Media.DISPLAY_NAME
        )
        try {
            context.contentResolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                projection,
                null,
                null,
                MediaStore.Video.Media.DATE_MODIFIED + " DESC"
            )?.use { cursor ->
                val idCol = cursor.getColumnIndex(MediaStore.Video.Media._ID)
                val dataCol = cursor.getColumnIndex(MediaStore.Video.Media.DATA)
                val sizeCol = cursor.getColumnIndex(MediaStore.Video.Media.SIZE)
                val dateCol = cursor.getColumnIndex(MediaStore.Video.Media.DATE_MODIFIED)
                val durCol = cursor.getColumnIndex(MediaStore.Video.Media.DURATION)
                val wCol = cursor.getColumnIndex(MediaStore.Video.Media.WIDTH)
                val hCol = cursor.getColumnIndex(MediaStore.Video.Media.HEIGHT)
                val nameCol = cursor.getColumnIndex(MediaStore.Video.Media.DISPLAY_NAME)

                while (cursor.moveToNext()) {
                    val id = if (idCol >= 0) cursor.getLong(idCol) else continue
                    val path = if (dataCol >= 0) cursor.getString(dataCol) else null
                    val uri = ContentUris.withAppendedId(
                        MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id
                    ).toString()

                    val row = HashMap<String, Any>()
                    row["path"] = path ?: uri
                    row["uri"] = uri
                    row["size"] = if (sizeCol >= 0) cursor.getLong(sizeCol) else 0L
                    row["modified"] =
                        if (dateCol >= 0) cursor.getLong(dateCol) * 1000L else 0L
                    row["duration"] = if (durCol >= 0) cursor.getLong(durCol) else 0L
                    row["width"] = if (wCol >= 0) cursor.getInt(wCol) else 0
                    row["height"] = if (hCol >= 0) cursor.getInt(hCol) else 0
                    row["name"] =
                        if (nameCol >= 0) (cursor.getString(nameCol) ?: "") else ""
                    out.add(row)
                }
            }
        } catch (_: Exception) {
        }
        return out
    }

    /** Every audio track MediaStore knows about. */
    fun queryAudio(context: Context): List<HashMap<String, Any>> {
        val out = ArrayList<HashMap<String, Any>>()
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM
        )
        try {
            context.contentResolver.query(
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                projection,
                MediaStore.Audio.Media.IS_MUSIC + " != 0",
                null,
                MediaStore.Audio.Media.DATE_MODIFIED + " DESC"
            )?.use { cursor ->
                val idCol = cursor.getColumnIndex(MediaStore.Audio.Media._ID)
                val dataCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
                val sizeCol = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)
                val dateCol = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_MODIFIED)
                val durCol = cursor.getColumnIndex(MediaStore.Audio.Media.DURATION)
                val titleCol = cursor.getColumnIndex(MediaStore.Audio.Media.TITLE)
                val artistCol = cursor.getColumnIndex(MediaStore.Audio.Media.ARTIST)
                val albumCol = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM)

                while (cursor.moveToNext()) {
                    val id = if (idCol >= 0) cursor.getLong(idCol) else continue
                    val path = if (dataCol >= 0) cursor.getString(dataCol) else null
                    val uri = ContentUris.withAppendedId(
                        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id
                    ).toString()

                    val row = HashMap<String, Any>()
                    row["path"] = path ?: uri
                    row["uri"] = uri
                    row["size"] = if (sizeCol >= 0) cursor.getLong(sizeCol) else 0L
                    row["modified"] =
                        if (dateCol >= 0) cursor.getLong(dateCol) * 1000L else 0L
                    row["duration"] = if (durCol >= 0) cursor.getLong(durCol) else 0L
                    row["title"] = if (titleCol >= 0) (cursor.getString(titleCol) ?: "") else ""
                    row["artist"] = if (artistCol >= 0) (cursor.getString(artistCol) ?: "") else ""
                    row["album"] = if (albumCol >= 0) (cursor.getString(albumCol) ?: "") else ""
                    out.add(row)
                }
            }
        } catch (_: Exception) {
        }
        return out
    }

    /**
     * Deletes a file and removes its MediaStore row.
     *
     * The plain File delete only succeeds when we own the file or hold
     * All-files access, so we always follow up with a MediaStore delete,
     * which is what actually removes third-party files on Android 11+.
     */
    fun deleteFile(context: Context, path: String): Boolean {
        var deleted = false

        try {
            val file = File(path)
            if (file.exists() && file.delete()) deleted = true
        } catch (_: Exception) {
        }

        try {
            val rows = context.contentResolver.delete(
                MediaStore.Files.getContentUri("external"),
                MediaStore.Files.FileColumns.DATA + "=?",
                arrayOf(path)
            )
            if (rows > 0) deleted = true
        } catch (_: Exception) {
        }

        if (deleted) scanFile(context, path)
        return deleted || !File(path).exists()
    }

    /** Tells MediaStore a path changed so the library stays in sync. */
    fun scanFile(context: Context, path: String) {
        try {
            MediaScannerConnection.scanFile(context, arrayOf(path), null, null)
        } catch (_: Exception) {
        }
    }
}
