package net.nearlink.core;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.LongSupplier;

/**
 * One device's message engine: contacts, outgoing queue, relay storage, inbox,
 * receipts, duplicate/replay suppression, expiry, and binary Spray-and-Wait
 * forwarding decisions (Spyropoulos et al., WDTN 2005). Transport-agnostic:
 * a {@link SyncSession} drives it over any byte stream (Bluetooth RFCOMM, TCP, ...).
 *
 * All public methods are synchronized; state is persisted after every mutation.
 */
public final class Node {

    public static final class Config {
        public long lifetimeMs = 3L * 24 * 3600 * 1000;   // default message lifetime
        public long maxLifetimeMs = 7L * 24 * 3600 * 1000; // reject longer-lived bundles
        public long clockSkewMs = 10 * 60 * 1000;         // tolerate peers' clocks this far ahead
        public int initialCopies = 8;                      // Spray-and-Wait L
        public int hopLimit = 8;
        public int maxRelayBundles = 500;
        public int maxReceipts = 2000;
        public int maxSeen = 20000;
        public boolean acceptFromStrangers = false;        // only contacts may message me
    }

    public enum Role { OWN, RELAY }
    public enum Status { QUEUED, FORWARDED, DELIVERED, EXPIRED }

    public static final class Held { public Bundle bundle; public Role role; long storedAt; }
    public static final class Outgoing {
        public String msgId, toId, text; public long created, expires; public Status status = Status.QUEUED;
        public int relayHandoffs; public long deliveredAt;
        /** Human-readable, deliberately conservative status line. */
        public String describe() {
            switch (status) {
                case QUEUED: return "Queued on this phone - not yet sent to anyone";
                case FORWARDED: return "Carried by " + relayHandoffs + " other device(s) - delivery NOT confirmed";
                case DELIVERED: return "Delivered (recipient signed a receipt)";
                default: return "Expired - never confirmed delivered";
            }
        }
    }
    public static final class Incoming { public String msgId, fromId, text; public long sentAt, receivedAt; }

    /** Result codes carried in BUNDLE_ACK frames. */
    public static final int ACK_RELAYED = 0, ACK_DELIVERED = 1, ACK_DUPLICATE = 2, ACK_INVALID = 3,
            ACK_FULL = 4, ACK_EXPIRED = 5, ACK_REFUSED = 6;

    public final Identity me;
    public final Config cfg;
    private final Store store;
    private final LongSupplier clock;
    private final Map<String, Contact> contacts = new LinkedHashMap<>();
    private final Map<String, Held> held = new LinkedHashMap<>();
    private final Map<String, Receipt> receipts = new LinkedHashMap<>();
    private final Map<String, Long> seen = new LinkedHashMap<>();     // msgId -> expiresMs (dedupe / replay)
    private final Map<String, Outgoing> outgoing = new LinkedHashMap<>();
    private final List<Incoming> inbox = new ArrayList<>();
    private final List<String> log = new ArrayList<>();

    public Node(Identity me, Store store, LongSupplier clock, Config cfg) throws IOException {
        this.me = me; this.store = store; this.clock = clock; this.cfg = cfg;
        byte[] saved = store.load();
        if (saved != null) {
            try { restore(saved); } catch (Bytes.MalformedException e) { throw new IOException("corrupt state: " + e.getMessage()); }
        }
    }

    public String idHex() { return Bytes.hex(me.id); }
    public long now() { return clock.getAsLong(); }

    // ------------------------------------------------------------------ user API
    public synchronized void addContact(Contact c) throws IOException { contacts.put(c.idHex(), c); persist(); }
    public synchronized List<Contact> contacts() { return new ArrayList<>(contacts.values()); }
    public synchronized Contact contact(String idHex) { return contacts.get(idHex); }

    public synchronized String send(String toIdHex, String text) throws IOException, GeneralSecurityException {
        Contact to = contacts.get(toIdHex);
        if (to == null) throw new IllegalArgumentException("unknown contact");
        long now = now();
        Bundle b = Sealer.seal(me, to, text, now, cfg.lifetimeMs, cfg.initialCopies, cfg.hopLimit);
        Held h = new Held(); h.bundle = b; h.role = Role.OWN; h.storedAt = now;
        held.put(b.idHex(), h);
        seen.put(b.idHex(), b.expiresMs);
        Outgoing o = new Outgoing(); o.msgId = b.idHex(); o.toId = toIdHex; o.text = text; o.created = now; o.expires = b.expiresMs;
        outgoing.put(o.msgId, o);
        persist();
        return o.msgId;
    }

    public synchronized List<Outgoing> outgoing() { return new ArrayList<>(outgoing.values()); }
    public synchronized Outgoing outgoing(String msgId) { return outgoing.get(msgId); }
    public synchronized List<Incoming> inbox() { return new ArrayList<>(inbox); }
    public synchronized int heldCount() { return held.size(); }
    public synchronized int relayCount() { int n = 0; for (Held h : held.values()) if (h.role == Role.RELAY) n++; return n; }
    public synchronized int receiptCount() { return receipts.size(); }
    public synchronized List<Receipt> receipts() { return new ArrayList<>(receipts.values()); }
    public synchronized boolean holds(String msgId) { return held.containsKey(msgId); }
    public synchronized List<String> drainLog() { List<String> l = new ArrayList<>(log); log.clear(); return l; }

    /** Removes expired state. Call periodically and at the start of each sync. */
    public synchronized void sweep() throws IOException {
        long now = now();
        held.values().removeIf(h -> h.bundle.expiresMs <= now);
        receipts.values().removeIf(r -> r.expiresMs <= now);
        seen.values().removeIf(e -> e <= now);
        for (Outgoing o : outgoing.values())
            if (o.status != Status.DELIVERED && o.expires <= now) o.status = Status.EXPIRED;
        persist();
    }

    // ------------------------------------------------------------------ sync hooks
    /** IDs we already know about (held, receipted, or seen): peer should not send these. */
    synchronized List<byte[]> summary(int max) {
        List<byte[]> ids = new ArrayList<>();
        for (String s : seen.keySet()) { if (ids.size() >= max) break; ids.add(Bytes.hex(s)); }
        return ids;
    }

    synchronized List<byte[]> receiptSummary(int max) {
        List<byte[]> ids = new ArrayList<>();
        for (String s : receipts.keySet()) { if (ids.size() >= max) break; ids.add(Bytes.hex(s)); }
        return ids;
    }

    synchronized List<Receipt> receiptsFor(java.util.Set<String> peerHas) {
        List<Receipt> out = new ArrayList<>();
        for (Receipt r : receipts.values()) if (!peerHas.contains(r.idHex())) out.add(r);
        return out;
    }

    /**
     * Forwarding decision (binary Spray-and-Wait):
     *   peer is the destination            -> send (copies unchanged)
     *   copies > 1 and hops remain         -> hand floor(copies/2) to peer
     *   otherwise (wait phase)             -> keep; only direct delivery
     */
    synchronized List<Bundle> bundlesFor(byte[] peerId, java.util.Set<String> peerHas) {
        long now = now();
        List<Bundle> out = new ArrayList<>();
        for (Held h : held.values()) {
            Bundle b = h.bundle;
            if (b.expiresMs <= now || peerHas.contains(b.idHex()) || receipts.containsKey(b.idHex())) continue;
            if (Arrays.equals(b.recipientId, peerId)) out.add(b.copyWith(b.copies, b.hopCount + 1));
            else if (b.copies > 1 && b.hopCount + 1 < b.hopLimit) out.add(b.copyWith(b.copies / 2, b.hopCount + 1));
        }
        return out;
    }

    /** Peer confirmed it stored/accepted a bundle we sent. */
    synchronized void onAck(byte[] peerId, byte[] msgId, int code, int copiesGiven) throws IOException {
        String id = Bytes.hex(msgId);
        Held h = held.get(id);
        if (h == null) return;
        if (code == ACK_RELAYED) {
            h.bundle.copies = Math.max(1, h.bundle.copies - copiesGiven);
            Outgoing o = outgoing.get(id);
            if (o != null && o.status == Status.QUEUED) o.status = Status.FORWARDED;
            if (o != null && o.status == Status.FORWARDED) o.relayHandoffs++;
            persist();
        }
        // ACK_DELIVERED is NOT trusted on its own: we wait for the signed receipt.
    }

    /** Handles an incoming bundle; returns an ACK_* code. */
    synchronized int acceptBundle(Bundle b, Receipt[] receiptOut) throws IOException {
        long now = now();
        String id = b.idHex();
        if (b.expiresMs <= now) return ACK_EXPIRED;
        if (b.createdMs > now + cfg.clockSkewMs || b.expiresMs - b.createdMs > cfg.maxLifetimeMs
                || b.expiresMs <= b.createdMs || b.hopCount > b.hopLimit || b.copies < 1) return ACK_INVALID;

        if (Arrays.equals(b.recipientId, me.id)) {
            Receipt existing = receipts.get(id);
            if (existing != null) { receiptOut[0] = existing; return ACK_DUPLICATE; }
            if (seen.containsKey(id)) return ACK_DUPLICATE;
            Sealer.Opened m;
            try { m = Sealer.open(me, b); }
            catch (GeneralSecurityException | Bytes.MalformedException e) { log.add("reject " + id + ": " + e.getMessage()); return ACK_INVALID; }
            String from = Bytes.hex(m.senderId);
            if (!cfg.acceptFromStrangers && !contacts.containsKey(from)) { log.add("refused message from unknown sender " + from); return ACK_REFUSED; }
            Incoming in = new Incoming(); in.msgId = id; in.fromId = from; in.text = m.text; in.sentAt = m.sentAt; in.receivedAt = now;
            inbox.add(in);
            seen.put(id, b.expiresMs);
            Receipt r = Receipt.create(me, b.msgId, b.expiresMs);
            receipts.put(id, r);
            receiptOut[0] = r;
            persist();
            return ACK_DELIVERED;
        }

        if (seen.containsKey(id) || receipts.containsKey(id)) return ACK_DUPLICATE;
        if (relayCount() >= cfg.maxRelayBundles) return ACK_FULL;
        Held h = new Held(); h.bundle = b; h.role = Role.RELAY; h.storedAt = now;
        held.put(id, h);
        seen.put(id, b.expiresMs);
        trimSeen();
        persist();
        return ACK_RELAYED;
    }

    /** Handles an incoming receipt. Returns true if it was new and valid. */
    synchronized boolean acceptReceipt(Receipt r) throws IOException {
        String id = r.idHex();
        if (r.expiresMs <= now() || receipts.containsKey(id)) return false;
        Held h = held.get(id);
        Outgoing o = outgoing.get(id);
        if (h != null) {
            if (!r.validFor(h.bundle)) { log.add("forged receipt ignored for " + id); return false; }
            held.remove(id);
            if (o != null) { o.status = Status.DELIVERED; o.deliveredAt = now(); }
        } else {
            if (!r.selfValid()) return false;
            if (receipts.size() >= cfg.maxReceipts) return false;
        }
        receipts.put(id, r);
        seen.put(id, r.expiresMs);
        persist();
        return true;
    }

    private void trimSeen() {
        while (seen.size() > cfg.maxSeen) { String k = seen.keySet().iterator().next(); seen.remove(k); }
    }

    // ------------------------------------------------------------------ persistence
    private void persist() throws IOException {
        Bytes.Out o = new Bytes.Out().bytes(Bytes.utf8("NLS1"));
        o.u32(contacts.size()); for (Contact c : contacts.values()) o.var16(Bytes.utf8(c.card()));
        o.u32(held.size()); for (Held h : held.values()) o.u8(h.role.ordinal()).u64(h.storedAt).var16(h.bundle.encode());
        o.u32(receipts.size()); for (Receipt r : receipts.values()) o.var16(r.encode());
        o.u32(seen.size()); for (Map.Entry<String, Long> e : seen.entrySet()) o.bytes(Bytes.hex(e.getKey())).u64(e.getValue());
        o.u32(outgoing.size());
        for (Outgoing g : outgoing.values())
            o.bytes(Bytes.hex(g.msgId)).bytes(Bytes.hex(g.toId)).var16(Bytes.utf8(g.text)).u64(g.created).u64(g.expires)
             .u8(g.status.ordinal()).u32(g.relayHandoffs).u64(g.deliveredAt);
        o.u32(inbox.size());
        for (Incoming i : inbox) o.bytes(Bytes.hex(i.msgId)).bytes(Bytes.hex(i.fromId)).var16(Bytes.utf8(i.text)).u64(i.sentAt).u64(i.receivedAt);
        store.save(o.done());
    }

    private void restore(byte[] d) throws Bytes.MalformedException {
        Bytes.In in = new Bytes.In(d);
        if (!"NLS1".equals(new String(in.bytes(4), StandardCharsets.UTF_8))) throw new Bytes.MalformedException("bad state magic");
        for (int n = in.u32(); n > 0; n--) { Contact c = Contact.parseCard(new String(in.var16(4096), StandardCharsets.UTF_8)); contacts.put(c.idHex(), c); }
        for (int n = in.u32(); n > 0; n--) {
            Held h = new Held(); h.role = Role.values()[in.u8()]; h.storedAt = in.u64(); h.bundle = Bundle.decode(in.var16(65535));
            held.put(h.bundle.idHex(), h);
        }
        for (int n = in.u32(); n > 0; n--) { Receipt r = Receipt.decode(in.var16(1024)); receipts.put(r.idHex(), r); }
        for (int n = in.u32(); n > 0; n--) seen.put(Bytes.hex(in.bytes(16)), in.u64());
        for (int n = in.u32(); n > 0; n--) {
            Outgoing g = new Outgoing(); g.msgId = Bytes.hex(in.bytes(16)); g.toId = Bytes.hex(in.bytes(32));
            g.text = new String(in.var16(65535), StandardCharsets.UTF_8); g.created = in.u64(); g.expires = in.u64();
            g.status = Status.values()[in.u8()]; g.relayHandoffs = in.u32(); g.deliveredAt = in.u64();
            outgoing.put(g.msgId, g);
        }
        for (int n = in.u32(); n > 0; n--) {
            Incoming i = new Incoming(); i.msgId = Bytes.hex(in.bytes(16)); i.fromId = Bytes.hex(in.bytes(32));
            i.text = new String(in.var16(65535), StandardCharsets.UTF_8); i.sentAt = in.u64(); i.receivedAt = in.u64();
            inbox.add(i);
        }
        in.end();
    }
}
