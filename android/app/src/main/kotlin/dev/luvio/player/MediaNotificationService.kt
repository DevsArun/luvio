package dev.luvio.player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle

/**
 * Foreground service that owns the lockscreen / notification-shade media
 * controls for Luvio Player.
 *
 * Dart drives it through [MainActivity]'s method channel. Button presses are
 * routed back to Dart through [actionListener], so all real playback logic
 * stays in PlayerProvider - this class only mirrors state.
 */
class MediaNotificationService : Service() {

    companion object {
        const val CHANNEL_ID = "luvio_playback"
        const val NOTIFICATION_ID = 4211

        const val ACTION_UPDATE = "dev.luvio.player.UPDATE"
        const val ACTION_PLAY_PAUSE = "dev.luvio.player.PLAY_PAUSE"
        const val ACTION_NEXT = "dev.luvio.player.NEXT"
        const val ACTION_PREVIOUS = "dev.luvio.player.PREVIOUS"
        const val ACTION_REWIND = "dev.luvio.player.REWIND"
        const val ACTION_FORWARD = "dev.luvio.player.FORWARD"
        const val ACTION_STOP = "dev.luvio.player.STOP"

        const val EXTRA_TITLE = "title"
        const val EXTRA_SUBTITLE = "subtitle"
        const val EXTRA_PLAYING = "playing"
        const val EXTRA_POSITION = "position"
        const val EXTRA_DURATION = "duration"
        const val EXTRA_HAS_NEXT = "hasNext"
        const val EXTRA_HAS_PREVIOUS = "hasPrevious"

        /** Set by MainActivity so button presses reach Dart. */
        @Volatile
        var actionListener: ((String) -> Unit)? = null

        fun update(
            context: Context,
            title: String,
            subtitle: String,
            playing: Boolean,
            positionMs: Long,
            durationMs: Long,
            hasNext: Boolean,
            hasPrevious: Boolean
        ) {
            val intent = Intent(context, MediaNotificationService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_SUBTITLE, subtitle)
                putExtra(EXTRA_PLAYING, playing)
                putExtra(EXTRA_POSITION, positionMs)
                putExtra(EXTRA_DURATION, durationMs)
                putExtra(EXTRA_HAS_NEXT, hasNext)
                putExtra(EXTRA_HAS_PREVIOUS, hasPrevious)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, MediaNotificationService::class.java).apply {
                action = ACTION_STOP
            }
            try {
                context.startService(intent)
            } catch (_: Exception) {
                // App may already be shutting down.
            }
        }
    }

    private var session: MediaSessionCompat? = null
    private var started = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        session = MediaSessionCompat(this, "LuvioPlayer").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() = dispatch(ACTION_PLAY_PAUSE)
                override fun onPause() = dispatch(ACTION_PLAY_PAUSE)
                override fun onSkipToNext() = dispatch(ACTION_NEXT)
                override fun onSkipToPrevious() = dispatch(ACTION_PREVIOUS)
                override fun onStop() = dispatch(ACTION_STOP)
                override fun onSeekTo(pos: Long) {
                    actionListener?.invoke("seek:$pos")
                }
            })
            isActive = true
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_UPDATE -> showNotification(intent)
            ACTION_STOP -> {
                dispatch(ACTION_STOP)
                shutdown()
            }
            ACTION_PLAY_PAUSE, ACTION_NEXT, ACTION_PREVIOUS,
            ACTION_REWIND, ACTION_FORWARD -> dispatch(intent.action!!)
            else -> {
                // Unknown start (e.g. system restart) - nothing to show.
                if (!started) stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    private fun dispatch(action: String) {
        actionListener?.invoke(action)
    }

    private fun showNotification(intent: Intent) {
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "Luvio Player"
        val subtitle = intent.getStringExtra(EXTRA_SUBTITLE) ?: ""
        val playing = intent.getBooleanExtra(EXTRA_PLAYING, false)
        val position = intent.getLongExtra(EXTRA_POSITION, 0L)
        val duration = intent.getLongExtra(EXTRA_DURATION, 0L)
        val hasNext = intent.getBooleanExtra(EXTRA_HAS_NEXT, false)
        val hasPrevious = intent.getBooleanExtra(EXTRA_HAS_PREVIOUS, false)

        val currentSession = session ?: return

        currentSession.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, subtitle)
                .putLong(MediaMetadataCompat.METADATA_KEY_DURATION, duration)
                .build()
        )

        currentSession.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_SEEK_TO or
                        PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                        PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackStateCompat.ACTION_STOP
                )
                .setState(
                    if (playing) PlaybackStateCompat.STATE_PLAYING
                    else PlaybackStateCompat.STATE_PAUSED,
                    position,
                    if (playing) 1.0f else 0.0f
                )
                .build()
        )

        val contentIntent = packageManager
            .getLaunchIntentForPackage(packageName)
            ?.let {
                PendingIntent.getActivity(
                    this, 0, it,
                    PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentImmutableFlag()
                )
            }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText(subtitle)
            .setOngoing(playing)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setDeleteIntent(actionIntent(ACTION_STOP))

        if (contentIntent != null) builder.setContentIntent(contentIntent)

        val compactIndices = ArrayList<Int>()
        var index = 0

        if (hasPrevious) {
            builder.addAction(
                android.R.drawable.ic_media_previous, "Previous",
                actionIntent(ACTION_PREVIOUS)
            )
            index++
        }

        builder.addAction(
            android.R.drawable.ic_media_rew, "Rewind",
            actionIntent(ACTION_REWIND)
        )
        index++

        builder.addAction(
            if (playing) android.R.drawable.ic_media_pause
            else android.R.drawable.ic_media_play,
            if (playing) "Pause" else "Play",
            actionIntent(ACTION_PLAY_PAUSE)
        )
        compactIndices.add(index)
        index++

        builder.addAction(
            android.R.drawable.ic_media_ff, "Forward",
            actionIntent(ACTION_FORWARD)
        )
        index++

        if (hasNext) {
            builder.addAction(
                android.R.drawable.ic_media_next, "Next",
                actionIntent(ACTION_NEXT)
            )
            compactIndices.add(index)
        }

        val style = MediaStyle()
            .setMediaSession(currentSession.sessionToken)
            .setShowActionsInCompactView(*compactIndices.toIntArray())
        builder.setStyle(style)

        val notification: Notification = builder.build()

        if (!started) {
            startForeground(NOTIFICATION_ID, notification)
            started = true
        } else {
            val manager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, notification)
        }
    }

    private fun actionIntent(action: String): PendingIntent {
        val intent = Intent(this, MediaNotificationService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(
            this, action.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentImmutableFlag()
        )
    }

    private fun pendingIntentImmutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Playback",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Media controls for the currently playing item"
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun shutdown() {
        started = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    override fun onDestroy() {
        session?.isActive = false
        session?.release()
        session = null
        started = false
        super.onDestroy()
    }
}
