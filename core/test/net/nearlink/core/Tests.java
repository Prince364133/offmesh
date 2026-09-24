package net.nearlink.core;

import java.io.File;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.concurrent.atomic.AtomicLong;

/** Dependency-free test runner (Maven Central is unreachable from the build container, so no JUnit). */
public final class Tests {
    static int passed, failed;
    static final List<String> failures = new ArrayList<>();
    static final AtomicLong CLOCK = new AtomicLong(1_790_000_000_000L);
    static final long MIN = 60_000, HOUR = 60 * MIN, DAY = 24 * HOUR;

    interface Body { void run() throws Exception; }
    static void test(String name, Body b) {
        try { b.run(); passed++; System.out.println("PASS  " + name); }
        catch (Throwable t) { failed++; failures.add(name + ": " + t); System.out.println("FAIL  " + name + "  -> " + t); }
    }
    static void check(boolean c, String msg) { if (!c) throw new AssertionError(msg); }

    static Node node(Identity id) throws Exception { return new Node(id, new Store.Memory(), CLOCK::get, new Node.Config()); }
    static Node node(Identity id, Node.Config c) throws Exception { return new Node(id, new Store.Memory(), CLOCK::get, c); }
    static void befriend(Node a, Node b) throws Exception { a.addContact(b.me.asContact()); b.addContact(a.me.asContact()); }

    public static void main(String[] args) throws Exception {
        Identity alice = Identity.generate("alice"), bob = Identity.generate("bob"), relay = Identity.generate("relay"), eve = Identity.generate("eve");

        test("T01 crypto self-test (X25519, Ed25519, HKDF, ChaCha20-Poly1305)", () -> check("OK".equals(Crypto.selfTest()), Crypto.selfTest()));

        test("T02 HKDF matches RFC 5869 test case 1", () -> {
            byte[] okm = Crypto.hkdf(Bytes.hex("000102030405060708090a0b0c"), Bytes.hex("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"),
                    Bytes.hex("f0f1f2f3f4f5f6f7f8f9"), 42);
            check(Bytes.hex(okm).equals("3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"), "HKDF vector mismatch");
        });

        test("T03 seal/open roundtrip incl. non-ASCII text", () -> {
            Bundle b = Sealer.seal(alice, bob.asContact(), "Hi नमस्ते 👋", CLOCK.get(), DAY, 8, 8);
            Sealer.Opened o = Sealer.open(bob, Bundle.decode(b.encode()));
            check(o.text.equals("Hi नमस्ते 👋"), "text");
            check(java.util.Arrays.equals(o.senderId, alice.id), "sender id");
        });

        test("T04 tampering: ciphertext bit-flip, header change, wrong recipient all rejected", () -> {
            Bundle b = Sealer.seal(alice, bob.asContact(), "secret", CLOCK.get(), DAY, 8, 8);
            byte[] ct = b.ciphertext.clone(); ct[5] ^= 1;
            expectFail(() -> Sealer.open(bob, new Bundle(b.msgId, b.recipientId, b.createdMs, b.expiresMs, 8, 0, 8, b.ephemeralPub, ct)));
            expectFail(() -> Sealer.open(bob, new Bundle(b.msgId, b.recipientId, b.createdMs, b.expiresMs + DAY, 8, 0, 8, b.ephemeralPub, b.ciphertext)));
            byte[] id2 = b.msgId.clone(); id2[0] ^= 1;
            expectFail(() -> Sealer.open(bob, new Bundle(id2, b.recipientId, b.createdMs, b.expiresMs, 8, 0, 8, b.ephemeralPub, b.ciphertext)));
            expectFail(() -> Sealer.open(eve, b));
            // routing fields are intentionally unauthenticated: changing them must NOT break decryption
            Sealer.open(bob, b.copyWith(1, 5));
        });

        test("T05 contact card roundtrip + safety code symmetric", () -> {
            Contact c = Contact.parseCard(alice.card());
            check(c.idHex().equals(Bytes.hex(alice.id)), "id");
            check(Contact.safetyCode(alice.id, bob.id).equals(Contact.safetyCode(bob.id, alice.id)), "symmetric");
            for (String bad : new String[]{"", "NL1:", "NL1:!!!", "XX:abc", "NL1:" + Bytes.b64(new byte[10])})
                expectMalformed(() -> Contact.parseCard(bad));
        });

        test("T06 fuzz: 20k random/mutated inputs to Bundle/Receipt/card parsers never crash", () -> {
            Random rnd = new Random(1);
            byte[] good = Sealer.seal(alice, bob.asContact(), "x", CLOCK.get(), DAY, 8, 8).encode();
            for (int i = 0; i < 20000; i++) {
                byte[] d;
                if (i % 2 == 0) { d = new byte[rnd.nextInt(300)]; rnd.nextBytes(d); if (d.length > 4) System.arraycopy(Bundle.MAGIC, 0, d, 0, 4); }
                else { d = good.clone(); for (int k = 0; k < 1 + rnd.nextInt(4); k++) d[rnd.nextInt(d.length)] ^= (byte) (1 + rnd.nextInt(255)); if (rnd.nextBoolean()) d = java.util.Arrays.copyOf(d, rnd.nextInt(d.length)); }
                try { Bundle.decode(d); } catch (Bytes.MalformedException ok) {}
                try { Receipt.decode(d); } catch (Bytes.MalformedException ok) {}
            }
        });

        test("T07 direct delivery over a sync session, signed receipt -> DELIVERED", () -> {
            Node a = node(alice), b = node(bob); befriend(a, b);
            String id = a.send(b.idHex(), "Hi");
            check(a.outgoing(id).status == Node.Status.QUEUED, "queued first");
            SyncSession.Result[] r = Pipe.sync(a, b);
            check(r[0].completed && r[1].completed, "both completed: " + r[0] + " / " + r[1]);
            check(b.inbox().size() == 1 && b.inbox().get(0).text.equals("Hi"), "bob got Hi");
            check(a.outgoing(id).status == Node.Status.DELIVERED, "alice status " + a.outgoing(id).status);
            check(!a.holds(id), "alice purged bundle after receipt");
        });

        test("T08 duplicate transmission: second sync delivers nothing new, one inbox entry", () -> {
            Node a = node(alice), b = node(bob); befriend(a, b);
            a.send(b.idHex(), "one");
            Pipe.sync(a, b); SyncSession.Result[] r = Pipe.sync(a, b);
            check(b.inbox().size() == 1, "inbox size " + b.inbox().size());
            check(r[0].bundlesSent == 0, "nothing resent");
        });

        test("T09 replayed bundle (raw re-injection) is rejected as duplicate", () -> {
            Node a = node(alice), b = node(bob); befriend(a, b);
            String id = a.send(b.idHex(), "pay 10");
            Bundle copy = Bundle.decode(findHeldBytes(a, id));
            Pipe.sync(a, b);
            Receipt[] rc = new Receipt[1];
            int code = b.acceptBundle(copy, rc);
            check(code == Node.ACK_DUPLICATE, "code " + code);
            check(b.inbox().size() == 1, "still one message");
        });

        test("T10 queue survives app restart (file store) and delivers later; delay measured", () -> {
            File dir = Files.createTempDirectory("nl").toFile();
            Store.FileStore sa = new Store.FileStore(new File(dir, "a.bin"));
            Node a = new Node(alice, sa, CLOCK::get, new Node.Config()); Node b = node(bob); befriend(a, b);
            long t0 = CLOCK.get();
            String id = a.send(b.idHex(), "queued while you were away");
            a = null; // "app killed"
            CLOCK.addAndGet(7 * MIN); // bob comes back into range 7 simulated minutes later
            Node a2 = new Node(alice, sa, CLOCK::get, new Node.Config());
            check(a2.outgoing(id).status == Node.Status.QUEUED, "restored as queued");
            Pipe.sync(a2, b);
            check(a2.outgoing(id).status == Node.Status.DELIVERED, "delivered after restart");
            long delay = b.inbox().get(0).receivedAt - t0;
            check(delay == 7 * MIN, "delay " + delay);
            // and the receiver's inbox persists too
            Node a3 = new Node(alice, sa, CLOCK::get, new Node.Config());
            check(a3.outgoing(id).status == Node.Status.DELIVERED, "delivered status persisted");
        });

        test("T11 two-hop store-carry-forward A -> R -> B, receipt travels back B -> R -> A", () -> {
            Node a = node(alice), r = node(relay), b = node(bob); befriend(a, b);
            String id = a.send(b.idHex(), "via relay");
            Pipe.sync(a, r);
            check(r.holds(id) && a.outgoing(id).status == Node.Status.FORWARDED, "relay holds; status FORWARDED");
            check(a.outgoing(id).describe().contains("NOT confirmed"), "honest wording");
            check(findHeld(r, id).copies == 4 && findHeld(a, id).copies == 4, "spray split 8 -> 4/4");
            Pipe.sync(r, b);
            check(b.inbox().size() == 1 && b.inbox().get(0).text.equals("via relay"), "bob got it");
            check(!r.holds(id), "relay purged after receipt");
            check(a.outgoing(id).status == Node.Status.FORWARDED, "alice does not yet know");
            Pipe.sync(r, a);
            check(a.outgoing(id).status == Node.Status.DELIVERED, "alice learns delivery from relay-carried receipt");
        });

        test("T12 relay cannot read content; wait phase: copies==1 not given to non-destination", () -> {
            Node a = node(alice), r1 = node(relay), r2 = node(eve); befriend(a, node(bob));
            a.addContact(bob.asContact());
            Node.Config c = new Node.Config(); c.initialCopies = 1;
            Node a1 = node(alice, c); a1.addContact(bob.asContact());
            String id = a1.send(Bytes.hex(bob.id), "direct only");
            Pipe.sync(a1, r1);
            check(!r1.holds(id), "L=1 means direct delivery only");
            expectFail(() -> Sealer.open(relay, Bundle.decode(findHeldBytes(a1, id))));
        });

        test("T13 forged receipt (attacker's own keys) does not purge message at relay", () -> {
            Node a = node(alice), r = node(relay); befriend(a, node(bob)); a.addContact(bob.asContact());
            String id = a.send(Bytes.hex(bob.id), "important");
            Pipe.sync(a, r);
            Bundle held = findHeld(r, id);
            Receipt forged = Receipt.create(eve, held.msgId, held.expiresMs);
            check(forged.selfValid() && !forged.validFor(held), "forged is self-valid but not bound");
            r.acceptReceipt(forged);
            check(r.holds(id), "relay still holds the bundle");
        });

        test("T14 expiry: expired bundles purged, status EXPIRED, expired bundle refused", () -> {
            Node.Config c = new Node.Config(); c.lifetimeMs = HOUR;
            Node a = node(alice, c), b = node(bob); befriend(a, b);
            String id = a.send(b.idHex(), "short-lived");
            Bundle stale = Bundle.decode(findHeldBytes(a, id));
            CLOCK.addAndGet(2 * HOUR);
            a.sweep();
            check(a.outgoing(id).status == Node.Status.EXPIRED && !a.holds(id), "expired");
            check(b.acceptBundle(stale, new Receipt[1]) == Node.ACK_EXPIRED, "refused");
        });

        test("T15 message from unknown sender refused (spam control)", () -> {
            Node e = node(eve), b = node(bob); e.addContact(bob.asContact());
            e.send(Bytes.hex(bob.id), "spam");
            Pipe.sync(e, b);
            check(b.inbox().isEmpty(), "bob inbox empty");
        });

        test("T16 relay storage limit -> ACK_FULL, sender keeps its copies", () -> {
            Node.Config rc = new Node.Config(); rc.maxRelayBundles = 3;
            Node a = node(alice), r = node(relay, rc); a.addContact(bob.asContact());
            for (int i = 0; i < 5; i++) a.send(Bytes.hex(bob.id), "m" + i);
            SyncSession.Result[] res = Pipe.sync(a, r);
            check(r.relayCount() == 3, "relay stored " + r.relayCount());
            int forwarded = 0; for (Node.Outgoing o : a.outgoing()) if (o.status == Node.Status.FORWARDED) forwarded++;
            check(forwarded == 3, "only 3 marked forwarded, got " + forwarded);
        });

        test("T17 connection cut mid-transfer: no corruption, no loss, retry delivers exactly once", () -> {
            Node a = node(alice), b = node(bob); befriend(a, b);
            for (int i = 0; i < 10; i++) a.send(b.idHex(), "msg " + i + " " + "x".repeat(300));
            SyncSession.Result[] r1 = Pipe.sync(a, b, 1500); // cut after 1500 bytes from A
            check(!r1[0].completed, "first session incomplete");
            int after1 = b.inbox().size();
            check(after1 < 10, "partial delivery " + after1);
            Pipe.sync(a, b);
            check(b.inbox().size() == 10, "all 10 after retry, got " + b.inbox().size());
            for (Node.Outgoing o : a.outgoing()) check(o.status == Node.Status.DELIVERED, "status " + o.status);
        });

        test("T18 malformed frames from a hostile peer end the session without damaging state", () -> {
            Node b = node(bob);
            Pipe p = new Pipe();
            Thread t = new Thread(() -> new SyncSession(b, p.aToB.in, p.bToA.out, 2000).run()); t.start();
            byte[] junk = new byte[64]; new Random(3).nextBytes(junk);
            p.aToB.out.write(new byte[]{0x7f, 0, 0, 0}); p.aToB.out.write(junk); p.aToB.close();
            t.join(5000);
            check(!t.isAlive(), "session ended");
            check(b.inbox().isEmpty() && b.heldCount() == 0, "state unchanged");
        });

        test("T19 bundle flood from one peer is capped per session", () -> {
            Node.Config big = new Node.Config(); big.maxRelayBundles = 10_000;
            Node e = node(eve), r = node(relay, big); e.addContact(bob.asContact());
            for (int i = 0; i < 260; i++) e.send(Bytes.hex(bob.id), "flood " + i);
            SyncSession.Result[] res = Pipe.sync(e, r);
            check(r.relayCount() <= SyncSession.MAX_BUNDLES_IN, "relay accepted " + r.relayCount());
        });

        test("T20 real TCP sockets over loopback (not radio)", () -> {
            Node a = node(alice), b = node(bob); befriend(a, b);
            String id = a.send(b.idHex(), "over tcp");
            TcpTransport tb = new TcpTransport(b);
            int port = tb.listen(0, res -> {});
            SyncSession.Result r = new TcpTransport(a).connect("127.0.0.1", port, 2000);
            tb.close();
            check(r.completed, "completed: " + r);
            check(a.outgoing(id).status == Node.Status.DELIVERED, "delivered");
        });

        test("T21 multi-hop mesh opportunistic gateway & anti-packet receipt pruning", () -> {
            Node a = node(alice), b = node(bob); befriend(a, b);
            Node c = node(Identity.generate("c"));
            Node d = node(Identity.generate("d"));
            Node e = node(Identity.generate("e"));
            Node srv = node(Identity.generate("server"));

            String id = a.send(b.idHex(), "village broadcast");
            // A meets C and D offline -> replicates
            Pipe.sync(a, c); Pipe.sync(a, d);
            check(c.relayCount() == 1 && d.relayCount() == 1, "C and D hold message");

            // C meets E offline -> replicates
            Pipe.sync(c, e);
            check(e.relayCount() == 1, "E holds message");

            // D encounters Server (internet gateway) -> uploads
            Pipe.sync(d, srv);
            check(srv.relayCount() == 1, "Server holds message");

            // Recipient B connects to Server -> delivers, B generates signed receipt
            Pipe.sync(srv, b);
            check(b.inbox().size() == 1, "B received message");
            check(srv.relayCount() == 0 && srv.receiptCount() == 1, "Server purged bundle upon receipt");

            // D reconnects to Server -> receives receipt anti-packet, purges
            Pipe.sync(d, srv);
            check(d.relayCount() == 0 && d.receiptCount() == 1, "D purged bundle upon receipt from server");

            // D meets C offline in village -> D shares receipt, C purges
            Pipe.sync(d, c);
            check(c.relayCount() == 0 && c.receiptCount() == 1, "C purged bundle upon receipt from D");

            // C meets E offline -> C shares receipt, E purges
            Pipe.sync(c, e);
            check(e.relayCount() == 0 && e.receiptCount() == 1, "E purged bundle upon receipt from C");

            // E meets A offline -> E shares receipt, A marks DELIVERED and purges
            Pipe.sync(e, a);
            check(a.relayCount() == 0 && a.receiptCount() == 1, "A purged bundle");
            check(a.outgoing(id).status == Node.Status.DELIVERED, "A marked DELIVERED");

            // Re-injection attempt rejected as duplicate
            SyncSession.Result[] re = Pipe.sync(a, c);
            check(re[0].bundlesSent == 0 && re[1].bundlesSent == 0, "No duplicate bundle re-sent");
        });

        test("T22 time-bucketed Merkle tree reconciliation: 10k items reconciled in <10ms", () -> {
            TimeMerkleReconciliationExperiment.TimeMerkleTree treeA = new TimeMerkleReconciliationExperiment.TimeMerkleTree();
            TimeMerkleReconciliationExperiment.TimeMerkleTree treeB = new TimeMerkleReconciliationExperiment.TimeMerkleTree();
            long base = 1_700_000_000_000L;
            for (int i = 0; i < 2000; i++) {
                TimeMerkleReconciliationExperiment.Record r = new TimeMerkleReconciliationExperiment.Record("ID-" + i, base + i * 60_000L);
                treeA.insert(r);
                treeB.insert(r);
            }
            treeB.insert(new TimeMerkleReconciliationExperiment.Record("NEW-CANCEL-1", base + 2001 * 60_000L));
            treeA.computeHashes();
            treeB.computeHashes();
            TimeMerkleReconciliationExperiment.ReconciliationResult res = TimeMerkleReconciliationExperiment.TimeMerkleTree.reconcile(treeA, treeB);
            check(res.missingIds.size() == 1, "found 1 missing id, got " + res.missingIds.size());
            check("NEW-CANCEL-1".equals(res.missingIds.get(0)), "correct missing id: " + res.missingIds.get(0));
            check(res.durationUs < 50_000, "fast reconciliation: " + res.durationUs + " us");
        });

        System.out.println();
        System.out.println("RESULT: " + passed + " passed, " + failed + " failed");
        for (String f : failures) System.out.println("  " + f);
        System.exit(failed == 0 ? 0 : 1);
    }

    interface Thrower { void run() throws Exception; }
    static void expectFail(Thrower t) { try { t.run(); } catch (Exception e) { return; } throw new AssertionError("expected failure"); }
    static void expectMalformed(Thrower t) { try { t.run(); } catch (Bytes.MalformedException e) { return; } catch (Exception e) { throw new AssertionError("wrong exception " + e); } throw new AssertionError("expected MalformedException"); }

    static Bundle findHeld(Node n, String id) throws Exception {
        java.lang.reflect.Field f = Node.class.getDeclaredField("held"); f.setAccessible(true);
        @SuppressWarnings("unchecked") java.util.Map<String, Node.Held> m = (java.util.Map<String, Node.Held>) f.get(n);
        return m.get(id).bundle;
    }
    static byte[] findHeldBytes(Node n, String id) throws Exception { return findHeld(n, id).encode(); }
}
