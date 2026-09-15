package com.example.lstp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

class AnimalProximityMonitorService : Service() {
    private val executor: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null
    private var isChecking = false
    private var isScheduled = false
    private var mutedCurrentBreach = false
    private var lastBreachKeys = emptySet<String>()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification("Monitoring animal GPS distance"))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_ALARM -> {
                startAlarm()
                return START_STICKY
            }
            ACTION_STOP_ALARM -> {
                mutedCurrentBreach = true
                stopAlarm()
                return START_STICKY
            }
        }

        if (!isScheduled) {
            isScheduled = true
            executor.scheduleWithFixedDelay(
                { checkAnimalDistances() },
                0,
                CHECK_INTERVAL_SECONDS,
                TimeUnit.SECONDS
            )
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopAlarm()
        executor.shutdownNow()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkAnimalDistances() {
        if (isChecking) return
        isChecking = true

        try {
            val token = readFlutterPreference("access_token") ?: return stopAlarm()
            val currentUser = readCurrentUser()
            val animals = fetchAnimals(token, currentUser)
            val locations = animals.mapNotNull { animal ->
                fetchLatestLocation(token, animal.id)?.let { animal to it }
            }

            var maxDistance = 0.0
            val currentBreachKeys = mutableSetOf<String>()
            for (i in locations.indices) {
                for (j in i + 1 until locations.size) {
                    val distance = distanceMeters(locations[i].second, locations[j].second)
                    if (distance > DISTANCE_LIMIT_METERS) {
                        currentBreachKeys.add(
                            breachKey(locations[i].first.id, locations[j].first.id)
                        )
                    }
                    if (distance > maxDistance) {
                        maxDistance = distance
                    }
                }
            }

            if (currentBreachKeys != lastBreachKeys) {
                mutedCurrentBreach = false
            }
            lastBreachKeys = currentBreachKeys

            if (currentBreachKeys.isNotEmpty()) {
                if (!mutedCurrentBreach) {
                    startAlarm()
                }
                updateNotification("Animal GPS distance is ${"%.1f".format(maxDistance)}m")
            } else {
                mutedCurrentBreach = false
                stopAlarm()
                updateNotification("Monitoring animal GPS distance")
            }
        } catch (_: Exception) {
            stopAlarm()
            updateNotification("Animal distance monitor needs internet")
        } finally {
            isChecking = false
        }
    }

    private fun fetchAnimals(token: String, currentUser: UserInfo?): List<AnimalInfo> {
        val response = getJson(token, "$API_URL/animals/")
        val results = response.optJSONArray("results") ?: JSONArray()
        val activeAnimals = mutableListOf<AnimalInfo>()

        for (index in 0 until results.length()) {
            val item = results.optJSONObject(index) ?: continue
            if (item.optString("status").uppercase() != "ACTIVE") continue

            val ownerId = parseOwnerId(item)
            activeAnimals.add(
                AnimalInfo(
                    id = item.optInt("id"),
                    ownerId = ownerId,
                )
            )
        }

        val ownedAnimals = activeAnimals.filter { animal ->
            currentUser?.role != "FARMER" || animal.ownerId == currentUser.id
        }

        return if (ownedAnimals.isNotEmpty()) ownedAnimals else activeAnimals
    }

    private fun fetchLatestLocation(token: String, animalId: Int): GpsLocation? {
        val response = getLocationsArray(token, "$API_URL/animals/$animalId/locations/")
        if (response.length() == 0) return null

        val item = response.optJSONObject(0) ?: return null
        val latitude = item.optDouble("latitude", Double.NaN)
        val longitude = item.optDouble("longitude", Double.NaN)

        if (latitude !in -90.0..90.0 || longitude !in -180.0..180.0) return null
        return GpsLocation(latitude, longitude)
    }

    private fun getJson(token: String, endpoint: String): JSONObject {
        return JSONObject(readUrl(token, endpoint))
    }

    private fun getJsonArray(token: String, endpoint: String): JSONArray {
        return JSONArray(readUrl(token, endpoint))
    }

    private fun getLocationsArray(token: String, endpoint: String): JSONArray {
        val body = readUrl(token, endpoint).trim()
        if (body.startsWith("[")) return JSONArray(body)
        val json = JSONObject(body)
        return json.optJSONArray("results") ?: JSONArray()
    }

    private fun readUrl(token: String, endpoint: String): String {
        val connection = URL(endpoint).openConnection() as HttpURLConnection
        connection.requestMethod = "GET"
        connection.connectTimeout = 30000
        connection.readTimeout = 30000
        connection.setRequestProperty("Content-Type", "application/json")
        connection.setRequestProperty("Authorization", "Bearer $token")

        val stream = if (connection.responseCode in 200..299) {
            connection.inputStream
        } else {
            connection.errorStream
        }

        BufferedReader(InputStreamReader(stream)).use { reader ->
            val body = reader.readText()
            if (connection.responseCode !in 200..299) {
                throw IllegalStateException(body)
            }
            return body
        }
    }

    private fun parseOwnerId(item: JSONObject): Int {
        val owner = item.opt("owner")
        if (owner is Int) return owner
        if (owner is String) return owner.toIntOrNull() ?: 0
        if (owner is JSONObject) return owner.optInt("id", 0)

        return item.optInt("owner_id", 0)
    }

    private fun readCurrentUser(): UserInfo? {
        val userJson = readFlutterPreference("user_data") ?: return null
        val user = JSONObject(userJson)
        return UserInfo(
            id = user.optInt("id"),
            role = user.optString("role").uppercase(),
        )
    }

    private fun readFlutterPreference(key: String): String? {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return prefs.getString("flutter.$key", null)
    }

    private fun distanceMeters(a: GpsLocation, b: GpsLocation): Double {
        val earthRadius = 6371000.0
        val lat1 = Math.toRadians(a.latitude)
        val lat2 = Math.toRadians(b.latitude)
        val deltaLat = Math.toRadians(b.latitude - a.latitude)
        val deltaLng = Math.toRadians(b.longitude - a.longitude)

        val haversine = sin(deltaLat / 2) * sin(deltaLat / 2) +
            cos(lat1) * cos(lat2) * sin(deltaLng / 2) * sin(deltaLng / 2)
        val centralAngle = 2 * atan2(sqrt(haversine), sqrt(1 - haversine))
        return earthRadius * centralAngle
    }

    private fun breachKey(firstAnimalId: Int, secondAnimalId: Int): String {
        val smaller = minOf(firstAnimalId, secondAnimalId)
        val larger = maxOf(firstAnimalId, secondAnimalId)
        return "$smaller:$larger"
    }

    private fun startAlarm() {
        if (ringtone?.isPlaying == true) return

        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: Uri.EMPTY

        ringtone = RingtoneManager.getRingtone(applicationContext, alarmUri)?.apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                isLooping = true
            }
            play()
        }

        vibrator = getPhoneVibrator()
        val pattern = longArrayOf(0, 800, 400, 800, 400)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    private fun stopAlarm() {
        ringtone?.stop()
        ringtone = null
        vibrator?.cancel()
        vibrator = null
    }

    private fun getPhoneVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Animal distance monitor",
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun buildNotification(text: String): Notification {
        val activityIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            activityIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("LSTP animal distance alarm")
            .setContentText(text)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(text))
    }

    private data class AnimalInfo(val id: Int, val ownerId: Int)
    private data class UserInfo(val id: Int, val role: String)
    private data class GpsLocation(val latitude: Double, val longitude: Double)

    companion object {
        const val ACTION_START_ALARM = "com.example.lstp.START_PROXIMITY_ALARM"
        const val ACTION_STOP_ALARM = "com.example.lstp.STOP_PROXIMITY_ALARM"

        const val API_URL = "http://10.101.62.153:8000/api"
        const val CHECK_INTERVAL_SECONDS = 30L
        const val DISTANCE_LIMIT_METERS = 5.0
        const val CHANNEL_ID = "animal_proximity_monitor"
        const val NOTIFICATION_ID = 2301
    }
}
