package net.nearlink.core;

import java.nio.charset.StandardCharsets;

/** Public half of an identity, obtained in person via card/QR. */
public final class Contact {
    public final String name;
    public final byte[] signPub, dhPub, id;

    public Contact(String name, byte[] signPub, byte[] dhPub) {
        this.name = name; this.signPub = signPub.clone(); this.dhPub = dhPub.clone();
        this.id = Identity.idOf(signPub, dhPub);
    }

    public String idHex() { return Bytes.hex(id); }

    public String card() {
        return "NL1:" + Bytes.b64(new Bytes.Out().var16(Bytes.utf8(name)).bytes(signPub).bytes(dhPub).done());
    }

    public static Contact parseCard(String card) throws Bytes.MalformedException {
        if (card == null || !card.trim().startsWith("NL1:")) throw new Bytes.MalformedException("not a NearLink card");
        byte[] raw;
        try { raw = Bytes.unb64(card.trim().substring(4)); } catch (IllegalArgumentException e) { throw new Bytes.MalformedException("bad base64"); }
        Bytes.In in = new Bytes.In(raw);
        String name = new String(in.var16(64), StandardCharsets.UTF_8);
        Contact c = new Contact(name, in.bytes(32), in.bytes(32));
        in.end();
        return c;
    }

    /**
     * Short verification code both users can compare out loud (like Signal's safety number).
     * Symmetric: order-independent.
     */
    public static String safetyCode(byte[] idA, byte[] idB) {
        byte[] lo = compare(idA, idB) <= 0 ? idA : idB, hi = lo == idA ? idB : idA;
        String h = Bytes.hex(Crypto.sha256(Bytes.utf8("NL-safety"), lo, hi)).substring(0, 20);
        return h.replaceAll("(.{5})(?!$)", "$1 ");
    }
    private static int compare(byte[] a, byte[] b) {
        for (int i = 0; i < Math.min(a.length, b.length); i++) { int d = (a[i] & 0xff) - (b[i] & 0xff); if (d != 0) return d; }
        return a.length - b.length;
    }
}
