package net.offmesh.mobile;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

/** Versioned authenticated storage envelope, not a network protocol. */
public final class EncryptedStateCodec {
    private static final byte[] MAGIC = {'O', 'M', 'S', 1};
    public static final int MAX_PLAINTEXT = 64 * 1024 * 1024;
    public static final int MAX_ENCODED = MAX_PLAINTEXT + 4 + 12 + 16;
    private final SecretKey key;
    private final byte[] aad;

    public EncryptedStateCodec(SecretKey key, String purpose) {
        this.key = key;
        this.aad = ("offmesh-local-v1:" + purpose).getBytes(StandardCharsets.UTF_8);
    }

    public byte[] encrypt(byte[] plaintext) throws IOException {
        if (plaintext == null || plaintext.length > MAX_PLAINTEXT) throw new IOException("state too large");
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            // The provider generates a fresh IV. AndroidKeyStore forbids caller-supplied
            // encryption IVs for keys with randomizedEncryptionRequired=true.
            cipher.init(Cipher.ENCRYPT_MODE, key);
            cipher.updateAAD(aad);
            byte[] iv = cipher.getIV();
            if (iv.length != 12) throw new IOException("unsupported GCM IV length");
            byte[] ciphertext = cipher.doFinal(plaintext);
            byte[] out = new byte[MAGIC.length + iv.length + ciphertext.length];
            System.arraycopy(MAGIC, 0, out, 0, MAGIC.length);
            System.arraycopy(iv, 0, out, MAGIC.length, iv.length);
            System.arraycopy(ciphertext, 0, out, MAGIC.length + iv.length, ciphertext.length);
            return out;
        } catch (GeneralSecurityException e) {
            throw new IOException("cannot encrypt protected storage", e);
        }
    }

    public byte[] decrypt(byte[] encoded) throws IOException {
        if (encoded == null || encoded.length < 32 || encoded.length > MAX_ENCODED
                || !Arrays.equals(MAGIC, Arrays.copyOf(encoded, 4))) throw new IOException("invalid protected storage envelope");
        try {
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(128, encoded, 4, 12));
            cipher.updateAAD(aad);
            return cipher.doFinal(encoded, 16, encoded.length - 16);
        } catch (GeneralSecurityException e) {
            // Never replace corrupt state with a new identity or an empty inbox.
            throw new IOException("protected storage authentication failed", e);
        }
    }
}
