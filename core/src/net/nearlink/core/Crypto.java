package net.nearlink.core;

import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.SecureRandom;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import javax.crypto.Cipher;
import javax.crypto.KeyAgreement;
import javax.crypto.Mac;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

/**
 * Thin wrapper over standard JCA primitives. No custom cryptography:
 * X25519 (RFC 7748), Ed25519 (RFC 8032), HKDF-SHA256 (RFC 5869, standard
 * HMAC construction), ChaCha20-Poly1305 (RFC 8439), SHA-256.
 *
 * Public keys travel as raw 32-byte values; we convert to/from X.509 SPKI by
 * adding/removing the fixed 12-byte DER prefix defined in RFC 8410.
 */
public final class Crypto {
    private Crypto() {}

    public static final SecureRandom RNG = new SecureRandom();

    private static final byte[] ED25519_SPKI_PREFIX = Bytes.hex("302a300506032b6570032100");
    private static final byte[] X25519_SPKI_PREFIX = Bytes.hex("302a300506032b656e032100");


    // ---------- provider selection ----------
    private static volatile java.security.Provider provider; // null = platform default providers

    /** Use a specific JCA provider (e.g. BouncyCastle on Android versions whose platform lacks Ed25519/X25519). */
    public static void useProvider(java.security.Provider p) { provider = p; }
    public static String providerName() { return provider == null ? "platform" : provider.getName(); }

    private static KeyPairGenerator getKeyPairGenerator(String a) throws GeneralSecurityException { return provider == null ? KeyPairGenerator.getInstance(a) : KeyPairGenerator.getInstance(a, provider); }
    private static KeyFactory getKeyFactory(String a) throws GeneralSecurityException { return provider == null ? KeyFactory.getInstance(a) : KeyFactory.getInstance(a, provider); }
    private static Signature getSignature(String a) throws GeneralSecurityException { return provider == null ? Signature.getInstance(a) : Signature.getInstance(a, provider); }
    private static KeyAgreement getKeyAgreement(String a) throws GeneralSecurityException { return provider == null ? KeyAgreement.getInstance(a) : KeyAgreement.getInstance(a, provider); }
    private static Cipher getCipher(String a) throws GeneralSecurityException { return provider == null ? Cipher.getInstance(a) : Cipher.getInstance(a, provider); }
    private static Mac getMac(String a) throws GeneralSecurityException { return Mac.getInstance(a); }
    private static MessageDigest getMessageDigest(String a) throws GeneralSecurityException { return MessageDigest.getInstance(a); }

    public static byte[] random(int n) { byte[] b = new byte[n]; RNG.nextBytes(b); return b; }

    public static byte[] sha256(byte[]... parts) {
        try {
            MessageDigest md = getMessageDigest("SHA-256");
            for (byte[] p : parts) md.update(p);
            return md.digest();
        } catch (GeneralSecurityException e) { throw new IllegalStateException(e); }
    }

    // ---------- key generation / encoding ----------
    public static KeyPair genEd25519() {
        try { return getKeyPairGenerator("Ed25519").generateKeyPair(); }
        catch (GeneralSecurityException e) { throw new IllegalStateException(e); }
    }
    public static KeyPair genX25519() {
        try { return getKeyPairGenerator("X25519").generateKeyPair(); }
        catch (GeneralSecurityException e) { throw new IllegalStateException(e); }
    }

    public static byte[] rawPublic(PublicKey k) {
        byte[] enc = k.getEncoded();
        if (enc.length != 44) throw new IllegalStateException("unexpected SPKI length " + enc.length);
        return Bytes.slice(enc, 12, 32);
    }

    public static PublicKey edPublic(byte[] raw) throws GeneralSecurityException {
        check32(raw);
        return getKeyFactory("Ed25519").generatePublic(new X509EncodedKeySpec(Bytes.concat(ED25519_SPKI_PREFIX, raw)));
    }
    public static PublicKey xPublic(byte[] raw) throws GeneralSecurityException {
        check32(raw);
        return getKeyFactory("X25519").generatePublic(new X509EncodedKeySpec(Bytes.concat(X25519_SPKI_PREFIX, raw)));
    }
    public static PrivateKey edPrivate(byte[] pkcs8) throws GeneralSecurityException {
        return getKeyFactory("Ed25519").generatePrivate(new PKCS8EncodedKeySpec(pkcs8));
    }
    public static PrivateKey xPrivate(byte[] pkcs8) throws GeneralSecurityException {
        return getKeyFactory("X25519").generatePrivate(new PKCS8EncodedKeySpec(pkcs8));
    }
    private static void check32(byte[] raw) throws GeneralSecurityException {
        if (raw == null || raw.length != 32) throw new GeneralSecurityException("key must be 32 bytes");
    }

    // ---------- primitives ----------
    public static byte[] x25519(PrivateKey priv, byte[] peerRaw) throws GeneralSecurityException {
        KeyAgreement ka = getKeyAgreement("X25519");
        ka.init(priv);
        ka.doPhase(xPublic(peerRaw), true);
        byte[] s = ka.generateSecret();
        // RFC 7748 s6.1: reject all-zero output (low-order point).
        int acc = 0; for (byte b : s) acc |= b;
        if (acc == 0) throw new GeneralSecurityException("X25519 produced all-zero secret");
        return s;
    }

    public static byte[] sign(PrivateKey edPriv, byte[] msg) throws GeneralSecurityException {
        Signature s = getSignature("Ed25519");
        s.initSign(edPriv);
        s.update(msg);
        return s.sign();
    }

    public static boolean verify(byte[] edPubRaw, byte[] msg, byte[] sig) {
        try {
            if (sig == null || sig.length != 64) return false;
            Signature s = getSignature("Ed25519");
            s.initVerify(edPublic(edPubRaw));
            s.update(msg);
            return s.verify(sig);
        } catch (GeneralSecurityException | RuntimeException e) {
            return false;
        }
    }

    /** HKDF-SHA256 per RFC 5869. */
    public static byte[] hkdf(byte[] salt, byte[] ikm, byte[] info, int len) throws GeneralSecurityException {
        Mac mac = getMac("HmacSHA256");
        mac.init(new SecretKeySpec(salt.length == 0 ? new byte[32] : salt, "HmacSHA256"));
        byte[] prk = mac.doFinal(ikm);
        mac.init(new SecretKeySpec(prk, "HmacSHA256"));
        byte[] out = new byte[len];
        byte[] t = new byte[0];
        int pos = 0;
        for (int i = 1; pos < len; i++) {
            mac.update(t); mac.update(info); mac.update((byte) i);
            t = mac.doFinal();
            int n = Math.min(t.length, len - pos);
            System.arraycopy(t, 0, out, pos, n);
            pos += n;
        }
        return out;
    }

    public static byte[] aeadSeal(byte[] key, byte[] nonce, byte[] aad, byte[] pt) throws GeneralSecurityException {
        Cipher c = getCipher("ChaCha20-Poly1305");
        c.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key, "ChaCha20"), new IvParameterSpec(nonce));
        c.updateAAD(aad);
        return c.doFinal(pt);
    }

    public static byte[] aeadOpen(byte[] key, byte[] nonce, byte[] aad, byte[] ct) throws GeneralSecurityException {
        Cipher c = getCipher("ChaCha20-Poly1305");
        c.init(Cipher.DECRYPT_MODE, new SecretKeySpec(key, "ChaCha20"), new IvParameterSpec(nonce));
        c.updateAAD(aad);
        return c.doFinal(ct);
    }

    /** Runs every primitive once; used by the Android app to verify provider support on a real device. */
    public static String selfTest() {
        try {
            KeyPair ed = genEd25519(); KeyPair a = genX25519(); KeyPair b = genX25519();
            byte[] sig = sign(ed.getPrivate(), new byte[]{1, 2, 3});
            if (!verify(rawPublic(ed.getPublic()), new byte[]{1, 2, 3}, sig)) return "FAIL: Ed25519 verify";
            byte[] s1 = x25519(a.getPrivate(), rawPublic(b.getPublic()));
            byte[] s2 = x25519(b.getPrivate(), rawPublic(a.getPublic()));
            if (!java.util.Arrays.equals(s1, s2)) return "FAIL: X25519 mismatch";
            byte[] k = hkdf(new byte[16], s1, new byte[]{9}, 44);
            byte[] ct = aeadSeal(Bytes.slice(k, 0, 32), Bytes.slice(k, 32, 12), new byte[]{7}, new byte[]{42});
            byte[] pt = aeadOpen(Bytes.slice(k, 0, 32), Bytes.slice(k, 32, 12), new byte[]{7}, ct);
            if (pt.length != 1 || pt[0] != 42) return "FAIL: AEAD roundtrip";
            // Also check re-import from raw/PKCS8 works.
            edPrivate(ed.getPrivate().getEncoded()); xPrivate(a.getPrivate().getEncoded());
            return "OK";
        } catch (Throwable t) {
            return "FAIL: " + t;
        }
    }
}
