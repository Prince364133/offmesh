package net.offmesh.mobile

import android.util.AtomicFile
import net.nearlink.core.Store
import java.io.File
import java.io.IOException
import javax.crypto.SecretKey

/** Android atomic file + AndroidKeyStore-authenticated encryption. */
internal class ProtectedStore(file: File, key: SecretKey, purpose: String) : Store {
    private val atomic = AtomicFile(file)
    private val codec = EncryptedStateCodec(key, purpose)

    @Synchronized
    override fun load(): ByteArray? {
        if (!exists(atomic.baseFile)) return null
        return atomic.openRead().use { input ->
            if (input.channel.size() > EncryptedStateCodec.MAX_ENCODED) {
                throw IOException("protected storage too large")
            }
            codec.decrypt(input.readBytes())
        }
    }

    companion object {
        // AtomicFile.exists is not a public Android API. Include its legacy backup
        // so openRead can recover an interrupted replacement instead of resetting.
        fun exists(file: File): Boolean = file.exists() || File(file.path + ".bak").exists()
    }

    @Synchronized
    override fun save(data: ByteArray) {
        val encoded = codec.encrypt(data)
        val stream = atomic.startWrite()
        try {
            stream.write(encoded)
            // finishWrite fsyncs and commits; failed writes preserve the old file.
            atomic.finishWrite(stream)
        } catch (e: Exception) {
            atomic.failWrite(stream)
            throw IOException("cannot commit protected storage", e)
        }
    }
}
