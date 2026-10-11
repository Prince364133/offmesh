package net.offmesh.mobile

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import net.nearlink.core.Bytes
import net.nearlink.core.Contact
import net.nearlink.core.Crypto
import net.nearlink.core.Identity
import net.nearlink.core.Node
import net.nearlink.core.SyncSession
import net.nearlink.core.TcpTransport
import org.bouncycastle.jce.provider.BouncyCastleProvider
import java.io.File
import java.io.IOException
import java.net.InetSocketAddress
import java.net.Socket
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory

/** No private keys cross this channel. All crypto and protocol state live in Java. */
internal class EngineBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val appContext = activity.applicationContext
    private val channel = MethodChannel(messenger, "net.offmesh/engine.v1")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var closed = false
    @Volatile private var activeSocket: Socket? = null

    init {
        channel.setMethodCallHandler { call, result ->
            worker.execute {
                try {
                    val value = handle(call)
                    main.post { if (!closed) result.success(value) }
                } catch (e: Exception) {
                    // Fail closed; the UI must not manufacture an identity or success state.
                    main.post {
                        if (!closed) result.error("ENGINE_FAILURE", e.message ?: "Native engine operation failed", null)
                    }
                }
            }
        }
    }

    private fun handle(call: MethodCall): Any? {
        val host = EngineHost.get(appContext)
        val node = host.node
        return when (call.method) {
            "initialize", "snapshot" -> { node.sweep(); host.snapshot() }
            "addContact" -> {
                val contact = Contact.parseCard(call.argument<String>("card") ?: error("card required"))
                require(contact.idHex() != node.idHex()) { "Cannot add your own card" }
                node.addContact(contact)
                host.snapshot()
            }
            "sendMessage" -> {
                val text = call.argument<String>("text") ?: error("text required")
                require(text.isNotBlank()) { "Message cannot be empty" }
                node.send(call.argument<String>("recipientId") ?: error("recipientId required"), text)
                host.snapshot()
            }
            "setAppDisguise" -> {
                val disguise = call.argument<String>("disguise") ?: "OFFMESH"
                val pm = appContext.packageManager
                val pkg = appContext.packageName

                val mainComp = android.content.ComponentName(pkg, "$pkg.MainActivity")
                val notesComp = android.content.ComponentName(pkg, "$pkg.NotesAlias")
                val weatherComp = android.content.ComponentName(pkg, "$pkg.WeatherAlias")

                val disableState = android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                val enableState = android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED

                pm.setComponentEnabledSetting(notesComp, if (disguise == "NOTES") enableState else disableState, android.content.pm.PackageManager.DONT_KILL_APP)
                pm.setComponentEnabledSetting(weatherComp, if (disguise == "WEATHER") enableState else disableState, android.content.pm.PackageManager.DONT_KILL_APP)
                pm.setComponentEnabledSetting(mainComp, if (disguise == "OFFMESH") enableState else disableState, android.content.pm.PackageManager.DONT_KILL_APP)

                mapOf("success" to true, "disguise" to disguise)
            }
            "syncTcp" -> {
                val address = call.argument<String>("host")?.trim() ?: error("host required")
                val port = call.argument<Int>("port") ?: TcpTransport.DEFAULT_PORT
                require(address.isNotEmpty() && address.length <= 253 && !address.contains('/')) { "Invalid host" }
                require(port in 1..65535) { "Invalid port" }
                val socket = Socket()
                activeSocket = socket
                val session = try {
                    socket.use {
                        it.connect(InetSocketAddress(address, port), 5000)
                        it.soTimeout = 15000
                        it.tcpNoDelay = true
                        SyncSession(node, it.getInputStream(), it.getOutputStream(), 30000).run()
                    }
                } finally { activeSocket = null }
                if (!session.completed || session.error != null) throw IOException(session.error ?: "Session incomplete")
                mapOf(
                    "snapshot" to host.snapshot(),
                    "bundlesSent" to session.bundlesSent,
                    "bundlesReceived" to session.bundlesReceived,
                    "receiptsReceived" to session.receiptsIn,
                    "completed" to session.completed
                )
            }
            "remoteVibrate" -> {
                val vibrator = appContext.getSystemService(Context.VIBRATOR_SERVICE) as? android.os.Vibrator
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    val timings = longArrayOf(0, 150, 100, 150, 300, 150, 100, 150)
                    val amplitudes = intArrayOf(0, 255, 0, 255, 0, 255, 0, 255)
                    val effect = android.os.VibrationEffect.createWaveform(timings, amplitudes, -1)
                    vibrator?.vibrate(effect)
                } else {
                    @Suppress("DEPRECATION")
                    vibrator?.vibrate(longArrayOf(0, 150, 100, 150, 300, 150, 100, 150), -1)
                }
                mapOf("success" to true)
            }
            "remoteRingBell" -> {
                try {
                    val alertUri = android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_ALARM)
                        ?: android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_RINGTONE)
                        ?: android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION)
                    val ringtone = android.media.RingtoneManager.getRingtone(appContext, alertUri)
                    ringtone?.play()
                } catch (_: Exception) {}
                mapOf("success" to true)
            }
            "remoteFlashlight" -> {
                val cameraManager = appContext.getSystemService(Context.CAMERA_SERVICE) as? android.hardware.camera2.CameraManager
                val cameraId = cameraManager?.cameraIdList?.firstOrNull()
                if (cameraId != null && cameraManager != null) {
                    try {
                        cameraManager.setTorchMode(cameraId, true)
                        main.postDelayed({
                            try { cameraManager.setTorchMode(cameraId, false) } catch (_: Exception) {}
                        }, 2500)
                    } catch (_: Exception) {}
                }
                mapOf("success" to true)
            }
            "setScreenSecurity" -> {
                val secure = call.argument<Boolean>("secure") ?: true
                activity.runOnUiThread {
                    if (secure) {
                        activity.window.setFlags(
                            android.view.WindowManager.LayoutParams.FLAG_SECURE,
                            android.view.WindowManager.LayoutParams.FLAG_SECURE
                        )
                    } else {
                        activity.window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_SECURE)
                    }
                }
                mapOf("success" to true, "secure" to secure)
            }
            else -> throw UnsupportedOperationException("Unknown engine method: ${call.method}")
        }
    }

    fun cancelNetwork() {
        try { activeSocket?.close() } catch (_: IOException) { }
    }

    fun close() {
        closed = true
        cancelNetwork()
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}

/** Process-scoped node avoids duplicate in-memory writers after Activity recreation. */
private class EngineHost private constructor(context: Context) {
    val node: Node
    private val protection: String

    init {
        Crypto.useProvider(null)
        if (Crypto.selfTest() != "OK") Crypto.useProvider(BouncyCastleProvider())
        check(Crypto.selfTest() == "OK") { "Required cryptographic primitives unavailable" }

        val directory = File(context.noBackupFilesDir, "engine-v1")
        check(directory.isDirectory || directory.mkdirs()) { "Cannot create private engine storage" }
        val identityFile = File(directory, "identity.enc")
        val stateFile = File(directory, "state.enc")
        val identityExists = ProtectedStore.exists(identityFile)
        val stateExists = ProtectedStore.exists(stateFile)
        check(identityExists || !stateExists) { "Identity missing for existing state; refusing identity reset" }

        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val alias = "offmesh.local-storage.v1"
        val key = if (keyStore.containsAlias(alias)) {
            keyStore.getKey(alias, null) as SecretKey
        } else {
            check(!identityExists && !stateExists) { "Storage key missing; existing data cannot be decrypted" }
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
                init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .setRandomizedEncryptionRequired(true)
                    .build())
                generateKey()
            }
        }
        val identityStore = ProtectedStore(identityFile, key, "identity")
        val saved = identityStore.load()
        val identity = if (saved == null) {
            Identity.generate("OffMesh user").also {
                val privateBytes = it.exportPrivate()
                try { identityStore.save(privateBytes) } finally { privateBytes.fill(0) }
            }
        } else {
            try { Identity.importPrivate(saved) } finally { saved.fill(0) }
        }
        val config = Node.Config().apply {
            // No relay transport is enabled in this increment. Explicitly refuse
            // third-party storage rather than silently opting the user into relay.
            maxRelayBundles = 0
        }
        node = Node(identity, ProtectedStore(stateFile, key, "state:${Bytes.hex(identity.id)}"), System::currentTimeMillis, config)
        protection = try {
            val info = SecretKeyFactory.getInstance(key.algorithm, "AndroidKeyStore")
                .getKeySpec(key, KeyInfo::class.java) as KeyInfo
            @Suppress("DEPRECATION")
            if (info.isInsideSecureHardware) "Android Keystore (hardware-backed wrapping key)"
            else "Android Keystore (software-backed wrapping key)"
        } catch (_: Exception) { "Android Keystore (hardware backing unknown)" }
    }

    fun snapshot(): Map<String, Any> = synchronized(node) {
        val me = node.me.asContact()
        val messages = node.outgoing().map { message ->
            mapOf<String, Any>(
                "id" to message.msgId, "toIdHex" to message.toId,
                "fromIdHex" to me.idHex(), "text" to message.text,
                "isOutgoing" to true, "timestampMs" to message.created,
                "status" to message.status.name.lowercase(),
                "relayHandoffs" to message.relayHandoffs, "deliveredAtMs" to message.deliveredAt
            )
        } + node.inbox().map { message ->
            mapOf<String, Any>(
                "id" to message.msgId, "toIdHex" to me.idHex(),
                "fromIdHex" to message.fromId, "text" to message.text,
                "isOutgoing" to false, "timestampMs" to message.sentAt,
                "status" to "delivered", "deliveredAtMs" to message.receivedAt,
                "relayHandoffs" to 0
            )
        }
        mapOf(
            "me" to contactMap(me),
            "contacts" to node.contacts().map { contactMap(it) },
            "messages" to messages,
            "storageProtection" to protection,
            "cryptoProvider" to Crypto.providerName()
        )
    }

    private fun contactMap(contact: Contact) = mapOf(
        "name" to contact.name, "idHex" to contact.idHex(),
        "signPubHex" to Bytes.hex(contact.signPub), "encPubHex" to Bytes.hex(contact.dhPub),
        "cardString" to contact.card()
    )

    companion object {
        private var instance: EngineHost? = null
        @Synchronized fun get(context: Context): EngineHost = instance ?: EngineHost(context).also { instance = it }
    }
}
