package net.nearlink.core;

/** Public half of an identity, obtained in person via card/QR. */
public final class Contact {
    public static final int MAX_NAME_BYTES = 64;
    private static final int MAX_CARD_CHARS = 4 + ((2 + MAX_NAME_BYTES + 64) * 4 + 2) / 3;
    public final String name;
    public final byte[] signPub, dhPub, id;

    public Contact(String name, byte[] signPub, byte[] dhPub) {
        if (Bytes.utf8(name).length > MAX_NAME_BYTES) throw new IllegalArgumentException("contact name too long");
        try {
            if (!Bytes.decodeUtf8(Bytes.utf8(name)).equals(name)) throw new IllegalArgumentException("invalid contact name");
        } catch (Bytes.MalformedException e) { throw new IllegalArgumentException(e); }
        Bytes.requireLength(signPub, 32, "signPub"); Bytes.requireLength(dhPub, 32, "dhPub");
        this.name = name; this.signPub = signPub.clone(); this.dhPub = dhPub.clone();
        this.id = Identity.idOf(signPub, dhPub);
    }

    public String idHex() { return Bytes.hex(id); }

    public String card() {
        return "NL1:" + Bytes.b64(new Bytes.Out().var16(Bytes.utf8(name)).bytes(signPub).bytes(dhPub).done());
    }

    public static Contact parseCard(String card) throws Bytes.MalformedException {
        if (card == null || card.length() > MAX_CARD_CHARS || !card.startsWith("NL1:")) throw new Bytes.MalformedException("not a canonical NearLink card");
        byte[] raw;
        String encoded = card.substring(4);
        try { raw = Bytes.unb64(encoded); } catch (IllegalArgumentException e) { throw new Bytes.MalformedException("bad base64"); }
        if (!Bytes.b64(raw).equals(encoded)) throw new Bytes.MalformedException("noncanonical base64");
        Bytes.In in = new Bytes.In(raw);
        String name = Bytes.decodeUtf8(in.var16(MAX_NAME_BYTES));
        Contact c = new Contact(name, in.bytes(32), in.bytes(32));
        in.end();
        return c;
    }

    /**
     * Short verification code both users can compare out loud (like Signal's safety number).
     * Symmetric: order-independent.
     */
    public static String safetyCode(byte[] idA, byte[] idB) {
        Bytes.requireLength(idA, 32, "idA"); Bytes.requireLength(idB, 32, "idB");
        byte[] lo = compare(idA, idB) <= 0 ? idA : idB, hi = lo == idA ? idB : idA;
        String h = Bytes.hex(Crypto.sha256(Bytes.utf8("NL-safety"), lo, hi)).substring(0, 20);
        return h.replaceAll("(.{5})(?!$)", "$1 ");
    }
    private static int compare(byte[] a, byte[] b) {
        for (int i = 0; i < Math.min(a.length, b.length); i++) { int d = (a[i] & 0xff) - (b[i] & 0xff); if (d != 0) return d; }
        return a.length - b.length;
    }
}
