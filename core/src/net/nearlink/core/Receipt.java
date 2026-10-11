package net.nearlink.core;

/**
 * Publicly verifiable delivery receipt ("anti-packet").
 *
 * Signed by the recipient's Ed25519 key over ("NLRCPT1" | msgId | expiresMs).
 * It carries the recipient's public keys so ANY node holding the bundle can check
 * SHA-256(signPub || dhPub) == bundle.recipientId and the signature, and then purge
 * its copy. Only the real recipient can therefore cancel a message in the network.
 *
 * Privacy cost: relays learn "recipient R received message M" (see SECURITY.md).
 */
public final class Receipt {
    public static final int LEN = 16 + 8 + 32 + 32 + 64;
    public final byte[] msgId, signPub, dhPub, sig;
    public final long expiresMs;

    public Receipt(byte[] msgId, long expiresMs, byte[] signPub, byte[] dhPub, byte[] sig) {
        Bytes.requireLength(msgId, 16, "msgId"); Bytes.requireLength(signPub, 32, "signPub");
        Bytes.requireLength(dhPub, 32, "dhPub"); Bytes.requireLength(sig, 64, "signature");
        if (expiresMs <= 0) throw new IllegalArgumentException("invalid receipt expiry");
        this.msgId = msgId.clone(); this.expiresMs = expiresMs;
        this.signPub = signPub.clone(); this.dhPub = dhPub.clone(); this.sig = sig.clone();
    }

    void validate() {
        Bytes.requireLength(msgId, 16, "msgId"); Bytes.requireLength(signPub, 32, "signPub");
        Bytes.requireLength(dhPub, 32, "dhPub"); Bytes.requireLength(sig, 64, "signature");
        if (expiresMs <= 0) throw new IllegalArgumentException("invalid receipt expiry");
    }

    static byte[] signedPart(byte[] msgId, long expiresMs) {
        Bytes.requireLength(msgId, 16, "msgId");
        if (expiresMs <= 0) throw new IllegalArgumentException("invalid receipt expiry");
        return new Bytes.Out().bytes(Bytes.utf8("NLRCPT1")).bytes(msgId).u64(expiresMs).done();
    }

    public static Receipt create(Identity me, byte[] msgId, long expiresMs) {
        try {
            return new Receipt(msgId, expiresMs, me.signPub, me.dhPub, Crypto.sign(me.signPriv, signedPart(msgId, expiresMs)));
        } catch (java.security.GeneralSecurityException e) { throw new IllegalStateException(e); }
    }

    public byte[] recipientId() { validate(); return Identity.idOf(signPub, dhPub); }

    /** Signature valid (self-consistent). Binding to a bundle is checked separately via recipientId(). */
    public boolean selfValid() {
        try { validate(); return Crypto.verify(signPub, signedPart(msgId, expiresMs), sig); }
        catch (RuntimeException e) { return false; }
    }

    public boolean validFor(Bundle b) {
        try {
            return b != null && java.util.Arrays.equals(b.msgId, msgId) && b.expiresMs == expiresMs
                    && java.util.Arrays.equals(recipientId(), b.recipientId) && selfValid();
        } catch (RuntimeException e) { return false; }
    }

    public byte[] encode() { return new Bytes.Out().bytes(msgId).u64(expiresMs).bytes(signPub).bytes(dhPub).bytes(sig).done(); }

    public static Receipt decode(byte[] d) throws Bytes.MalformedException {
        if (d == null || d.length != LEN) throw new Bytes.MalformedException("invalid receipt length");
        Bytes.In in = new Bytes.In(d);
        try {
            Receipt r = new Receipt(in.bytes(16), in.u64(), in.bytes(32), in.bytes(32), in.bytes(64));
            in.end();
            return r;
        } catch (IllegalArgumentException e) { throw new Bytes.MalformedException(e.getMessage()); }
    }

    public String idHex() { return Bytes.hex(msgId); }
}
