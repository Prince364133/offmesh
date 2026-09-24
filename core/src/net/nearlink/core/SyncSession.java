package net.nearlink.core;

import java.io.DataInputStream;
import java.io.DataOutputStream;
import java.io.EOFException;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

/**
 * Symmetric sync protocol run by BOTH ends of any reliable byte stream
 * (Bluetooth RFCOMM socket, TCP socket, in-memory pipe).
 *
 * Frame: len(u32, <= MAX_FRAME) | type(u8) | payload
 *   HELLO   : version(u8) | nodeId(32)
 *   SUMMARY : n(u16) | n * msgId(16) | m(u16) | m * msgId(16)
 *             first list: message ids already seen (don't send these bundles);
 *             second list: ids we already hold a delivery receipt for (anti-entropy, cf. epidemic routing)
 *   RECEIPT : Receipt.encode()
 *   BUNDLE  : Bundle.encode()
 *   ACK     : msgId(16) | code(u8)              link-level acceptance of a BUNDLE
 *   DONE    : (empty)                           sender has nothing more to offer
 *
 * The session finishes when both sides sent DONE and every BUNDLE we sent was ACKed,
 * or on timeout / disconnect. Interruption is safe: a bundle's local copy count only
 * changes after its ACK arrives, so an interrupted transfer is simply retried next contact.
 */
public final class SyncSession {
    public static final int VERSION = 1, MAX_FRAME = 16 * 1024, MAX_SUMMARY = 4000;
    public static final int MAX_BUNDLES_IN = 200, MAX_RECEIPTS_IN = 1000;
    static final int HELLO = 1, SUMMARY = 2, RECEIPT = 3, BUNDLE = 4, ACK = 5, DONE = 6;

    public static final class Result {
        public byte[] peerId; public int bundlesSent, bundlesAcked, bundlesReceived, delivered, receiptsIn, receiptsOut;
        public boolean completed; public String error;
        @Override public String toString() {
            return String.format("peer=%s sent=%d acked=%d recv=%d deliveredToMe=%d rcptIn=%d rcptOut=%d completed=%s%s",
                    peerId == null ? "?" : Bytes.hex(peerId).substring(0, 8), bundlesSent, bundlesAcked, bundlesReceived,
                    delivered, receiptsIn, receiptsOut, completed, error == null ? "" : " error=" + error);
        }
    }

    private final Node node;
    private final DataInputStream in;
    private final DataOutputStream out;
    private final long timeoutMs;
    private final Result res = new Result();
    private final CountDownLatch gotSummary = new CountDownLatch(1);
    private final CountDownLatch finished = new CountDownLatch(1);
    private final Set<String> peerHas = new HashSet<>();
    private final Set<String> peerReceipts = new HashSet<>();
    private final Map<String, Integer> pendingAcks = new HashMap<>(); // msgId -> copies given
    private volatile boolean peerDone;
    private volatile byte[] peerId;

    public SyncSession(Node node, InputStream in, OutputStream out, long timeoutMs) {
        this.node = node; this.in = new DataInputStream(in); this.out = new DataOutputStream(out); this.timeoutMs = timeoutMs;
    }

    public Result run() {
        Thread reader = new Thread(this::readLoop, "nl-sync-reader");
        reader.setDaemon(true);
        try {
            node.sweep();
            send(HELLO, new Bytes.Out().u8(VERSION).bytes(node.me.id).done());
            Bytes.Out s = new Bytes.Out();
            List<byte[]> ids = node.summary(MAX_SUMMARY);
            s.u16(ids.size()); for (byte[] id : ids) s.bytes(id);
            List<byte[]> rids = node.receiptSummary(MAX_SUMMARY);
            s.u16(rids.size()); for (byte[] id : rids) s.bytes(id);
            send(SUMMARY, s.done());
            reader.start();
            if (!gotSummary.await(timeoutMs, TimeUnit.MILLISECONDS)) throw new IOException("timeout waiting for peer summary");
            if (res.error != null) throw new IOException(res.error);

            Set<String> has, hasR;
            synchronized (peerHas) { has = new HashSet<>(peerHas); hasR = new HashSet<>(peerReceipts); }
            has.addAll(hasR);
            for (Receipt r : node.receiptsFor(hasR)) { send(RECEIPT, r.encode()); res.receiptsOut++; }
            for (Bundle b : node.bundlesFor(peerId, has)) {
                synchronized (pendingAcks) { pendingAcks.put(b.idHex(), b.copies); }
                send(BUNDLE, b.encode());
                res.bundlesSent++;
            }
            send(DONE, new byte[0]);
            long deadline = System.currentTimeMillis() + timeoutMs;
            while (System.currentTimeMillis() < deadline) {
                boolean acksDone; synchronized (pendingAcks) { acksDone = pendingAcks.isEmpty(); }
                if (acksDone && peerDone) { res.completed = true; break; }
                if (finished.await(50, TimeUnit.MILLISECONDS)) { // reader ended: re-check once, then stop
                    synchronized (pendingAcks) { acksDone = pendingAcks.isEmpty(); }
                    res.completed = acksDone && peerDone;
                    break;
                }
            }
            if (!res.completed && res.error == null) res.error = "incomplete (timeout or disconnect)";
        } catch (Exception e) {
            if (res.error == null) res.error = e.toString();
        }
        res.peerId = peerId;
        return res;
    }

    private void send(int type, byte[] payload) throws IOException {
        synchronized (out) {
            out.writeInt(payload.length + 1);
            out.writeByte(type);
            out.write(payload);
            out.flush();
        }
    }

    private void readLoop() {
        int bundlesIn = 0, receiptsIn = 0;
        try {
            while (true) {
                int len = in.readInt();
                if (len < 1 || len > MAX_FRAME) throw new IOException("bad frame length " + len);
                int type = in.readUnsignedByte();
                byte[] p = new byte[len - 1];
                in.readFully(p);
                Bytes.In r = new Bytes.In(p);
                switch (type) {
                    case HELLO: {
                        int v = r.u8(); byte[] id = r.bytes(32); r.end();
                        if (v != VERSION) throw new IOException("unsupported version " + v);
                        peerId = id; break;
                    }
                    case SUMMARY: {
                        if (peerId == null) throw new IOException("SUMMARY before HELLO");
                        int n = r.u16(); if (n > MAX_SUMMARY) throw new IOException("summary too large");
                        synchronized (peerHas) { for (int i = 0; i < n; i++) peerHas.add(Bytes.hex(r.bytes(16))); }
                        int m = r.u16(); if (m > MAX_SUMMARY) throw new IOException("summary too large");
                        synchronized (peerHas) { for (int i = 0; i < m; i++) peerReceipts.add(Bytes.hex(r.bytes(16))); }
                        r.end(); gotSummary.countDown(); break;
                    }
                    case RECEIPT: {
                        if (++receiptsIn > MAX_RECEIPTS_IN) throw new IOException("receipt flood");
                        if (node.acceptReceipt(Receipt.decode(p))) res.receiptsIn++;
                        break;
                    }
                    case BUNDLE: {
                        if (++bundlesIn > MAX_BUNDLES_IN) throw new IOException("bundle flood");
                        Bundle b;
                        try { b = Bundle.decode(p); } catch (Bytes.MalformedException e) { continue; } // drop malformed, keep session
                        Receipt[] rc = new Receipt[1];
                        int code = node.acceptBundle(b, rc);
                        res.bundlesReceived++;
                        if (code == Node.ACK_DELIVERED) res.delivered++;
                        // Receipt BEFORE ack, so the sender has it by the time its last ACK arrives.
                        if (rc[0] != null) { send(RECEIPT, rc[0].encode()); res.receiptsOut++; }
                        send(ACK, new Bytes.Out().bytes(b.msgId).u8(code).done());
                        break;
                    }
                    case ACK: {
                        byte[] id = r.bytes(16); int code = r.u8(); r.end();
                        Integer given; synchronized (pendingAcks) { given = pendingAcks.remove(Bytes.hex(id)); }
                        if (given != null) { res.bundlesAcked++; node.onAck(peerId, id, code, given); }
                        break;
                    }
                    case DONE: peerDone = true; break;
                    default: break; // unknown frame types ignored for forward compatibility
                }
            }
        } catch (EOFException e) {
            // peer closed
        } catch (Exception e) {
            if (res.error == null) res.error = e.toString();
        } finally {
            gotSummary.countDown();
            finished.countDown();
        }
    }
}
