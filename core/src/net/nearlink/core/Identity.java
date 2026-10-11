package net.nearlink.core;

import java.security.GeneralSecurityException;
import java.security.KeyPair;
import java.security.PrivateKey;

/**
 * A local user identity: an Ed25519 signing key and an X25519 key-agreement key.
 * The public "address" is id = SHA-256(signPub || dhPub). There are no phone
 * numbers, accounts or servers; identities are exchanged in person (QR / text card).
 */
public final class Identity {
    public final String name;
    public final byte[] signPub, dhPub, id;
    final PrivateKey signPriv, dhPriv;

    private Identity(String name, byte[] signPub, byte[] dhPub, PrivateKey signPriv, PrivateKey dhPriv) {
        Contact validated = new Contact(name, signPub, dhPub);
        this.name = validated.name; this.signPub = validated.signPub; this.dhPub = validated.dhPub;
        this.signPriv = signPriv; this.dhPriv = dhPriv;
        this.id = idOf(signPub, dhPub);
    }

    public static byte[] idOf(byte[] signPub, byte[] dhPub) {
        Bytes.requireLength(signPub, 32, "signPub"); Bytes.requireLength(dhPub, 32, "dhPub");
        return Crypto.sha256(signPub, dhPub);
    }

    public static Identity generate(String name) {
        KeyPair ed = Crypto.genEd25519(), x = Crypto.genX25519();
        return new Identity(name, Crypto.rawPublic(ed.getPublic()), Crypto.rawPublic(x.getPublic()), ed.getPrivate(), x.getPrivate());
    }

    /** Serialized form INCLUDING private keys. Callers must store it in protected storage. */
    public byte[] exportPrivate() {
        return new Bytes.Out().var16(Bytes.utf8(name)).bytes(signPub).bytes(dhPub)
                .var16(signPriv.getEncoded()).var16(dhPriv.getEncoded()).done();
    }

    public static Identity importPrivate(byte[] data) throws GeneralSecurityException, Bytes.MalformedException {
        if (data == null || data.length > 1024) throw new Bytes.MalformedException("invalid identity length");
        Bytes.In in = new Bytes.In(data);
        String name = Bytes.decodeUtf8(in.var16(Contact.MAX_NAME_BYTES));
        byte[] sp = in.bytes(32), dp = in.bytes(32);
        PrivateKey s = Crypto.edPrivate(in.var16(256)), d = Crypto.xPrivate(in.var16(256));
        in.end();
        byte[] challenge = Bytes.utf8("NL-identity-key-check-v1");
        if (!Crypto.verify(sp, challenge, Crypto.sign(s, challenge)))
            throw new GeneralSecurityException("signing public/private key mismatch");
        KeyPair probe = Crypto.genX25519();
        byte[] fromPrivate = Crypto.x25519(d, Crypto.rawPublic(probe.getPublic()));
        byte[] fromPublic = Crypto.x25519(probe.getPrivate(), dp);
        if (!java.security.MessageDigest.isEqual(fromPrivate, fromPublic))
            throw new GeneralSecurityException("DH public/private key mismatch");
        return new Identity(name, sp, dp, s, d);
    }

    public Contact asContact() { return new Contact(name, signPub, dhPub); }

    /** Contact card to show as QR code or text: "NL1:" + base64url(name, signPub, dhPub). */
    public String card() { return asContact().card(); }
}
