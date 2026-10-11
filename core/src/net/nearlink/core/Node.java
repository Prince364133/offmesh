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

        void validate() {
            if (lifetimeMs <= 0 || maxLifetimeMs < lifetimeMs || clockSkewMs < 0)
                throw new IllegalArgumentException("invalid time configuration");
            if (initialCopies < 1 || initialCopies > 255 || hopLimit < 1 || hopLimit > 255)
                throw new IllegalArgumentException("invalid routing configuration");
            if (maxRelayBundles < 0 || maxReceipts < 0 || maxSeen < 1)
                throw new IllegalArgumentException("invalid storage configuration");
        }
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
    private static final int MAX_STATE_ITEMS = 100_000;
    private static final int MAX_STATE_BYTES = 64 * 1024 * 1024;

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
        if (me == null || store == null || clock == null || cfg == null) throw new IllegalArgumentException("null node dependency");
        cfg.validate();
        this.me = me; this.store = store; this.clock = clock; this.cfg = cfg;
        byte[] saved = store.load();
        if (saved != null) {
            if (saved.length > MAX_STATE_BYTES) throw new IOException("state too large");
            try { restore(saved); }
            catch (Bytes.MalformedException | RuntimeException e) { throw new IOException("corrupt state: " + e.getMessage(), e); }
        }
    }

    public String idHex() { return Bytes.hex(me.id); }
    public long now() { return clock.getAsLong(); }

    // ------------------------------------------------------------------ user API
    public synchronized void addContact(Contact c) throws IOException {
        if (c == null) throw new IllegalArgumentException("contact must not be null");
        String id = c.idHex(); Contact previous = contacts.put(id, c);
        try { persist(); }
        catch (IOException e) { if (previous == null) contacts.remove(id); else contacts.put(id, previous); throw e; }
    }
    public synchronized List<Contact> contacts() { return new ArrayList<>(contacts.values()); }
    public synchronized Contact contact(String idHex) { return contacts.get(idHex); }

    public synchronized String send(String toIdHex, String text) throws IOException, GeneralSecurityException {
        if (toIdHex == null || toIdHex.length() != 64) throw new IllegalArgumentException("invalid recipient id");
        Contact to = contacts.get(toIdHex);
        if (to == null) throw new IllegalArgumentException("unknown contact");
        long now = now();
        Bundle b = Sealer.seal(me, to, text, now, cfg.lifetimeMs, cfg.initialCopies, cfg.hopLimit);
        Held h = new Held(); h.bundle = b; h.role = Role.OWN; h.storedAt = now;
        String id = b.idHex();
        Held previousHeld = held.put(id, h); Long previousSeen = seen.put(id, b.expiresMs);
        Outgoing o = new Outgoing(); o.msgId = id; o.toId = toIdHex; o.text = text; o.created = now; o.expires = b.expiresMs;
        Outgoing previousOutgoing = outgoing.put(o.msgId, o);
        try { persist(); }
        catch (IOException e) {
            if (previousHeld == null) held.remove(id); else held.put(id, previousHeld);
            if (previousSeen == null) seen.remove(id); else seen.put(id, previousSeen);
            if (previousOutgoing == null) outgoing.remove(id); else outgoing.put(id, previousOutgoing);
            throw e;
        }
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
        if (b == null || receiptOut == null || receiptOut.length == 0) throw new IllegalArgumentException("invalid bundle receiver arguments");
        receiptOut[0] = null;
        try { b.validate(); } catch (RuntimeException e) { return ACK_INVALID; }
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
            catch (GeneralSecurityException | Bytes.MalformedException | RuntimeException e) { log.add("reject " + id + ": " + e.getMessage()); return ACK_INVALID; }
            String from = Bytes.hex(m.senderId);
            if (!cfg.acceptFromStrangers && !contacts.containsKey(from)) { log.add("refused message from unknown sender " + from); return ACK_REFUSED; }
            Incoming in = new Incoming(); in.msgId = id; in.fromId = from; in.text = m.text; in.sentAt = m.sentAt; in.receivedAt = now;
            inbox.add(in);
            Long previousSeen = seen.put(id, b.expiresMs);
            Receipt r = Receipt.create(me, b.msgId, b.expiresMs);
            Receipt previousReceipt = receipts.put(id, r);
            receiptOut[0] = r;
            try { persist(); }
            catch (IOException e) {
                inbox.remove(inbox.size() - 1); if (previousSeen == null) seen.remove(id); else seen.put(id, previousSeen);
                if (previousReceipt == null) receipts.remove(id); else receipts.put(id, previousReceipt);
                receiptOut[0] = null; throw e;
            }
            return ACK_DELIVERED;
        }

        if (seen.containsKey(id) || receipts.containsKey(id)) return ACK_DUPLICATE;
        if (relayCount() >= cfg.maxRelayBundles) return ACK_FULL;
        Held h = new Held(); h.bundle = b; h.role = Role.RELAY; h.storedAt = now;
        held.put(id, h);
        Long previousSeen = seen.put(id, b.expiresMs);
        trimSeen();
        try { persist(); }
        catch (IOException e) {
            held.remove(id); if (previousSeen == null) seen.remove(id); else seen.put(id, previousSeen); throw e;
        }
        return ACK_RELAYED;
    }

    /** Handles an incoming receipt. Returns true if it was new and valid. */
    synchronized boolean acceptReceipt(Receipt r) throws IOException {
        if (r == null) throw new IllegalArgumentException("receipt must not be null");
        try { r.validate(); } catch (RuntimeException e) { return false; }
        String id = r.idHex();
        if (r.expiresMs <= now() || receipts.containsKey(id)) return false;
        Held h = held.get(id);
        // A receipt without a locally held bundle cannot be bound to anything. Keeping it
        // would let an attacker reserve an arbitrary 128-bit message id and suppress a
        // later valid bundle, so unknown receipts are deliberately discarded.
        if (h == null || !r.validFor(h.bundle)) { log.add("unbound receipt ignored for " + id); return false; }
        Outgoing o = outgoing.get(id);
        held.remove(id);
        Node.Status previousStatus = null; long previousDelivered = 0;
        if (o != null) { previousStatus = o.status; previousDelivered = o.deliveredAt; o.status = Status.DELIVERED; o.deliveredAt = now(); }
        Receipt previousReceipt = receipts.put(id, r); Long previousSeen = seen.put(id, r.expiresMs);
        try { persist(); }
        catch (IOException e) {
            held.put(id, h); if (o != null) { o.status = previousStatus; o.deliveredAt = previousDelivered; }
            if (previousReceipt == null) receipts.remove(id); else receipts.put(id, previousReceipt);
            if (previousSeen == null) seen.remove(id); else seen.put(id, previousSeen); throw e;
        }
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
        byte[] state = o.done();
        if (state.length > MAX_STATE_BYTES) throw new IOException("state too large");
        store.save(state);
    }

    private static int count(Bytes.In in, int max, String name) throws Bytes.MalformedException {
        int n = in.u32();
        if (n < 0 || n > max) throw new Bytes.MalformedException(name + " count out of range");
        return n;
    }

    private static long time(Bytes.In in, String name) throws Bytes.MalformedException {
        long t = in.u64();
        if (t < 0) throw new Bytes.MalformedException(name + " out of range");
        return t;
    }

    private void restore(byte[] d) throws Bytes.MalformedException {
        Bytes.In in = new Bytes.In(d);
        if (!"NLS1".equals(new String(in.bytes(4), StandardCharsets.UTF_8))) throw new Bytes.MalformedException("bad state magic");
        for (int n = count(in, MAX_STATE_ITEMS, "contact"); n > 0; n--) {
            Contact c = Contact.parseCard(Bytes.decodeUtf8(in.var16(512))); contacts.put(c.idHex(), c);
        }
        for (int n = count(in, MAX_STATE_ITEMS, "held"); n > 0; n--) {
            Held h = new Held(); int role = in.u8();
            if (role >= Role.values().length) throw new Bytes.MalformedException("invalid held role");
            h.role = Role.values()[role]; h.storedAt = time(in, "storedAt"); h.bundle = Bundle.decode(in.var16(Bundle.HEADER_LEN + Bundle.MAX_CT));
            if (held.put(h.bundle.idHex(), h) != null) throw new Bytes.MalformedException("duplicate held bundle");
        }
        for (int n = count(in, Math.min(MAX_STATE_ITEMS, cfg.maxReceipts), "receipt"); n > 0; n--) {
            Receipt r = Receipt.decode(in.var16(Receipt.LEN));
            if (receipts.put(r.idHex(), r) != null) throw new Bytes.MalformedException("duplicate receipt");
        }
        for (int n = count(in, cfg.maxSeen, "seen"); n > 0; n--) {
            String id = Bytes.hex(in.bytes(16)); long expires = time(in, "seen expiry");
            if (seen.put(id, expires) != null) throw new Bytes.MalformedException("duplicate seen id");
        }
        for (int n = count(in, MAX_STATE_ITEMS, "outgoing"); n > 0; n--) {
            Outgoing g = new Outgoing(); g.msgId = Bytes.hex(in.bytes(16)); g.toId = Bytes.hex(in.bytes(32));
            g.text = Bytes.decodeUtf8(in.var16(Sealer.MAX_BODY)); g.created = time(in, "outgoing created"); g.expires = time(in, "outgoing expiry");
            if (g.expires <= g.created) throw new Bytes.MalformedException("invalid outgoing timestamps");
            int status = in.u8(); if (status >= Status.values().length) throw new Bytes.MalformedException("invalid outgoing status");
            g.status = Status.values()[status]; g.relayHandoffs = in.u32();
            if (g.relayHandoffs < 0) throw new Bytes.MalformedException("relay handoffs out of range");
            g.deliveredAt = time(in, "deliveredAt");
            if (outgoing.put(g.msgId, g) != null) throw new Bytes.MalformedException("duplicate outgoing id");
        }
        for (int n = count(in, MAX_STATE_ITEMS, "inbox"); n > 0; n--) {
            Incoming i = new Incoming(); i.msgId = Bytes.hex(in.bytes(16)); i.fromId = Bytes.hex(in.bytes(32));
            i.text = Bytes.decodeUtf8(in.var16(Sealer.MAX_BODY)); i.sentAt = time(in, "sentAt"); i.receivedAt = time(in, "receivedAt");
            if (inbox.stream().anyMatch(old -> old.msgId.equals(i.msgId))) throw new Bytes.MalformedException("duplicate inbox id");
            inbox.add(i);
        }
        in.end();
    }
}
