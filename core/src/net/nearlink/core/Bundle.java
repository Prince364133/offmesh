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
        this.msgId = msgId; this.recipientId = recipientId; this.createdMs = createdMs; this.expiresMs = expiresMs;
        this.copies = copies; this.hopCount = hopCount; this.hopLimit = hopLimit;
        this.ephemeralPub = ephemeralPub; this.ciphertext = ciphertext;
    }

    public String idHex() { return Bytes.hex(msgId); }

    /** Associated data: every field an attacker must not be able to change undetected. */
    public static byte[] aad(byte[] msgId, byte[] recipientId, long created, long expires, byte[] eph) {
        return new Bytes.Out().bytes(MAGIC).bytes(msgId).bytes(recipientId).u64(created).u64(expires).bytes(eph).done();
    }
    public byte[] aad() { return aad(msgId, recipientId, createdMs, expiresMs, ephemeralPub); }

    public byte[] encode() {
        return new Bytes.Out().bytes(MAGIC).bytes(msgId).bytes(recipientId).u64(createdMs).u64(expiresMs)
                .u8(copies).u8(hopCount).u8(hopLimit).bytes(ephemeralPub).var16(ciphertext).done();
    }

    public static Bundle decode(byte[] data) throws Bytes.MalformedException {
        Bytes.In in = new Bytes.In(data);
        byte[] m = in.bytes(4);
        if (!java.util.Arrays.equals(m, MAGIC)) throw new Bytes.MalformedException("bad magic");
        Bundle b = new Bundle(in.bytes(16), in.bytes(32), in.u64(), in.u64(), in.u8(), in.u8(), in.u8(), in.bytes(32), in.var16(MAX_CT));
        in.end();
        if (b.ciphertext.length < 16) throw new Bytes.MalformedException("ciphertext too short");
        return b;
    }

    public Bundle copyWith(int newCopies, int newHopCount) {
        return new Bundle(msgId, recipientId, createdMs, expiresMs, newCopies, newHopCount, hopLimit, ephemeralPub, ciphertext);
    }
}
