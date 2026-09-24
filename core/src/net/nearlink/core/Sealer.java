package net.nearlink.core;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.KeyPair;
import java.util.Arrays;

/**
 * End-to-end sealing of a text message to one recipient.
 *
 * Construction (standard "ephemeral-static ECDH + AEAD, sign-then-encrypt"; no new primitives):
 *   eph <- X25519 keygen
 *   ss  = X25519(eph.priv, recipient.dhPub)
 *   key(32) || nonce(12) = HKDF-SHA256(salt = msgId, ikm = ss, info = "NLv1" | eph.pub | recipient.dhPub)
 *   inner = type | sender.signPub | sender.dhPub | sentAt | body | Ed25519sig
 *     sig covers "NLMSG1" | AAD | type | sender keys | sentAt | body   (AAD binds msgId, recipient, times, eph)
 *   ciphertext = ChaCha20-Poly1305(key, nonce, AAD, inner)
 *
 * Properties: confidentiality + integrity vs relays; sender authenticated to recipient;
 * sender identity hidden from relays. NOT provided: forward secrecy for the recipient's
 * static key, post-compromise security (future work: Double Ratchet / X3DH-style sessions).
 */
public final class Sealer {
    private Sealer() {}
    public static final int TYPE_TEXT = 1;
    public static final int MAX_BODY = 4000;
    static final byte[] INFO = Bytes.utf8("NLv1");

    public static final class Opened {
        public final byte[] senderSignPub, senderDhPub, senderId;
        public final long sentAt; public final int type; public final String text;
        Opened(byte[] s, byte[] d, long t, int type, String text) {
            senderSignPub = s; senderDhPub = d; senderId = Identity.idOf(s, d); sentAt = t; this.type = type; this.text = text;
        }
    }

    public static Bundle seal(Identity me, Contact to, String text, long now, long lifetimeMs, int copies, int hopLimit)
            throws GeneralSecurityException {
        byte[] body = text.getBytes(StandardCharsets.UTF_8);
        if (body.length > MAX_BODY) throw new IllegalArgumentException("message too long");
        byte[] msgId = Crypto.random(16);
        long expires = now + lifetimeMs;
        KeyPair eph = Crypto.genX25519();
        byte[] ephPub = Crypto.rawPublic(eph.getPublic());
        byte[] aad = Bundle.aad(msgId, to.id, now, expires, ephPub);

        byte[] toSign = new Bytes.Out().bytes(Bytes.utf8("NLMSG1")).bytes(aad).u8(TYPE_TEXT)
                .bytes(me.signPub).bytes(me.dhPub).u64(now).var16(body).done();
        byte[] sig = Crypto.sign(me.signPriv, toSign);
        byte[] inner = new Bytes.Out().u8(TYPE_TEXT).bytes(me.signPub).bytes(me.dhPub).u64(now).var16(body).bytes(sig).done();

        byte[] okm = kdf(Crypto.x25519(eph.getPrivate(), to.dhPub), msgId, ephPub, to.dhPub);
        byte[] ct = Crypto.aeadSeal(Bytes.slice(okm, 0, 32), Bytes.slice(okm, 32, 12), aad, inner);
        return new Bundle(msgId, to.id, now, expires, copies, 0, hopLimit, ephPub, ct);
    }

    private static byte[] kdf(byte[] ss, byte[] msgId, byte[] ephPub, byte[] rcptDh) throws GeneralSecurityException {
        return Crypto.hkdf(msgId, ss, Bytes.concat(INFO, ephPub, rcptDh), 44);
    }

    /** Opens a bundle addressed to {@code me}. Throws on any tampering or bad signature. */
    public static Opened open(Identity me, Bundle b) throws GeneralSecurityException, Bytes.MalformedException {
        if (!Arrays.equals(b.recipientId, me.id)) throw new GeneralSecurityException("not addressed to me");
        byte[] aad = b.aad();
        byte[] okm = kdf(Crypto.x25519(me.dhPriv, b.ephemeralPub), b.msgId, b.ephemeralPub, me.dhPub);
        byte[] inner = Crypto.aeadOpen(Bytes.slice(okm, 0, 32), Bytes.slice(okm, 32, 12), aad, b.ciphertext);
        Bytes.In in = new Bytes.In(inner);
        int type = in.u8();
        byte[] sp = in.bytes(32), dp = in.bytes(32);
        long sentAt = in.u64();
        byte[] body = in.var16(MAX_BODY);
        byte[] sig = in.bytes(64);
        in.end();
        byte[] toSign = new Bytes.Out().bytes(Bytes.utf8("NLMSG1")).bytes(aad).u8(type).bytes(sp).bytes(dp).u64(sentAt).var16(body).done();
        if (!Crypto.verify(sp, toSign, sig)) throw new GeneralSecurityException("bad sender signature");
        if (sentAt != b.createdMs) throw new GeneralSecurityException("timestamp mismatch");
        return new Opened(sp, dp, sentAt, type, new String(body, StandardCharsets.UTF_8));
    }
}
