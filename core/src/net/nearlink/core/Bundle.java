package net.nearlink.core;

/**
 * The unit that moves between devices (DTN terminology, cf. RFC 9171 "bundle").
 *
 * Wire format (big-endian):
 *   magic "NLB1"(4) | msgId(16) | recipientId(32) | createdMs(8) | expiresMs(8)
 *   | copies(1) | hopCount(1) | hopLimit(1) | ephemeralPub(32) | ctLen(2) | ciphertext
 *
 * Immutable header fields (magic..expires, ephemeralPub) are bound as AEAD associated
 * data and covered by the sender's signature. Routing fields (copies, hopCount,
 * hopLimit) are mutable by relays and therefore NOT authenticated; a malicious relay
 * can tamper with them (see SECURITY.md).
 */
public final class Bundle {
    public static final byte[] MAGIC = {'N', 'L', 'B', '1'};
    public static final int MAX_CT = 6 * 1024;
    public static final int HEADER_LEN = 4 + 16 + 32 + 8 + 8 + 3 + 32 + 2;

    public final byte[] msgId, recipientId, ephemeralPub, ciphertext;
    public final long createdMs, expiresMs;
    public int copies, hopCount, hopLimit;

    public Bundle(byte[] msgId, byte[] recipientId, long createdMs, long expiresMs,
                  int copies, int hopCount, int hopLimit, byte[] ephemeralPub, byte[] ciphertext) {
        Bytes.requireLength(msgId, 16, "msgId"); Bytes.requireLength(recipientId, 32, "recipientId");
        Bytes.requireLength(ephemeralPub, 32, "ephemeralPub");
        if (ciphertext == null || ciphertext.length < 16 || ciphertext.length > MAX_CT)
            throw new IllegalArgumentException("invalid ciphertext length");
        if (createdMs < 0 || expiresMs <= createdMs) throw new IllegalArgumentException("invalid bundle timestamps");
        this.msgId = msgId.clone(); this.recipientId = recipientId.clone(); this.createdMs = createdMs; this.expiresMs = expiresMs;
        this.copies = copies; this.hopCount = hopCount; this.hopLimit = hopLimit;
        this.ephemeralPub = ephemeralPub.clone(); this.ciphertext = ciphertext.clone();
        validateRouting();
    }

    public String idHex() { return Bytes.hex(msgId); }

    /** Associated data: every field an attacker must not be able to change undetected. */
    public static byte[] aad(byte[] msgId, byte[] recipientId, long created, long expires, byte[] eph) {
        return new Bytes.Out().bytes(MAGIC).bytes(msgId).bytes(recipientId).u64(created).u64(expires).bytes(eph).done();
    }
    public byte[] aad() { return aad(msgId, recipientId, createdMs, expiresMs, ephemeralPub); }

    void validate() {
        Bytes.requireLength(msgId, 16, "msgId"); Bytes.requireLength(recipientId, 32, "recipientId");
        Bytes.requireLength(ephemeralPub, 32, "ephemeralPub");
        if (ciphertext == null || ciphertext.length < 16 || ciphertext.length > MAX_CT)
            throw new IllegalArgumentException("invalid ciphertext length");
        if (createdMs < 0 || expiresMs <= createdMs) throw new IllegalArgumentException("invalid bundle timestamps");
        validateRouting();
    }

    private void validateRouting() {
        if (copies < 1 || copies > 255 || hopLimit < 1 || hopLimit > 255 || hopCount < 0 || hopCount > hopLimit)
            throw new IllegalArgumentException("invalid routing fields");
    }

    public byte[] encode() {
        validateRouting();
        return new Bytes.Out().bytes(MAGIC).bytes(msgId).bytes(recipientId).u64(createdMs).u64(expiresMs)
                .u8(copies).u8(hopCount).u8(hopLimit).bytes(ephemeralPub).var16(ciphertext).done();
    }

    public static Bundle decode(byte[] data) throws Bytes.MalformedException {
        if (data == null || data.length < HEADER_LEN + 16 || data.length > HEADER_LEN + MAX_CT)
            throw new Bytes.MalformedException("invalid bundle length");
        Bytes.In in = new Bytes.In(data);
        byte[] m = in.bytes(4);
        if (!java.util.Arrays.equals(m, MAGIC)) throw new Bytes.MalformedException("bad magic");
        try {
            Bundle b = new Bundle(in.bytes(16), in.bytes(32), in.u64(), in.u64(), in.u8(), in.u8(), in.u8(), in.bytes(32), in.var16(MAX_CT));
            in.end();
            return b;
        } catch (IllegalArgumentException e) { throw new Bytes.MalformedException(e.getMessage()); }
    }

    public Bundle copyWith(int newCopies, int newHopCount) {
        return new Bundle(msgId, recipientId, createdMs, expiresMs, newCopies, newHopCount, hopLimit, ephemeralPub, ciphertext);
    }
}
