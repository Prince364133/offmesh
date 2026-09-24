package net.nearlink.core;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;
import java.util.concurrent.atomic.AtomicLong;

/**
 * SIMULATION (not a radio experiment). Runs the real Node + SyncSession code over
 * in-memory links under a synthetic contact trace, to compare forwarding policies.
 *
 * Contact model ("campus"): N devices in G groups (e.g. hostels/classes). Each simulated
 * minute, every pair meets with probability pIntra (same group) or pInter (different group).
 * A meeting = one full sync session. This is a crude stand-in for real mobility traces
 * (e.g. CRAWDAD); results show relative trends only, not real-world latencies.
 */
public final class Simulator {
    public static void main(String[] a) throws Exception {
        int n = 24, groups = 3, msgs = 40, minutes = 360;
        double pIntra = 0.010, pInter = 0.0015;
        long seed = a.length > 0 ? Long.parseLong(a[0]) : 42;
        System.out.printf("SIMULATION  N=%d groups=%d msgs=%d horizon=%dmin pIntra=%.4f pInter=%.4f seed=%d%n",
                n, groups, msgs, minutes, pIntra, pInter, seed);
        System.out.println("policy          deliv@10m deliv@60m deliv@6h  medianLat(min)  meanRelayCopies/msg  bundleTransfers");
        for (int L : new int[]{1, 4, 8, 16, 255}) run(L, n, groups, msgs, minutes, pIntra, pInter, seed);
    }

    static void run(int L, int n, int groups, int msgs, int minutes, double pIntra, double pInter, long seed) throws Exception {
        Random rnd = new Random(seed);
        AtomicLong clock = new AtomicLong(1_790_000_000_000L);
        Node.Config cfg = new Node.Config();
        cfg.initialCopies = L; cfg.hopLimit = 255; cfg.acceptFromStrangers = true; cfg.maxRelayBundles = 10_000;
        Node[] nodes = new Node[n];
        for (int i = 0; i < n; i++) nodes[i] = new Node(Identity.generate("n" + i), new Store.Memory(), clock::get, cfg);
        List<String> ids = new ArrayList<>(); List<Integer> src = new ArrayList<>(); List<Integer> dst = new ArrayList<>();
        long t0 = clock.get();
        for (int m = 0; m < msgs; m++) {
            int s = rnd.nextInt(n), d; do { d = rnd.nextInt(n); } while (d == s || d / (n / groups) == s / (n / groups) && rnd.nextDouble() < 0.5);
            nodes[s].addContact(nodes[d].me.asContact());
            ids.add(nodes[s].send(nodes[d].idHex(), "m" + m)); src.add(s); dst.add(d);
        }
        long[] deliveredAt = new long[msgs]; Arrays.fill(deliveredAt, -1);
        int transfers = 0; double copySamples = 0; int samples = 0;
        for (int minute = 1; minute <= minutes; minute++) {
            clock.set(t0 + minute * 60_000L);
            for (int i = 0; i < n; i++) for (int j = i + 1; j < n; j++) {
                boolean same = i / (n / groups) == j / (n / groups);
                if (rnd.nextDouble() < (same ? pIntra : pInter)) {
                    SyncSession.Result[] r = Pipe.sync(nodes[i], nodes[j]);
                    transfers += r[0].bundlesSent + r[1].bundlesSent;
                }
            }
            for (int m = 0; m < msgs; m++) if (deliveredAt[m] < 0) {
                for (Node.Incoming in : nodes[dst.get(m)].inbox()) if (in.msgId.equals(ids.get(m))) { deliveredAt[m] = minute; break; }
            }
            if (minute % 30 == 0) { int c = 0; for (Node x : nodes) c += x.relayCount(); copySamples += (double) c / msgs; samples++; }
        }
        int d10 = 0, d60 = 0, d6h = 0; List<Long> lat = new ArrayList<>();
        for (long t : deliveredAt) { if (t >= 0) { lat.add(t); if (t <= 10) d10++; if (t <= 60) d60++; if (t <= 360) d6h++; } }
        lat.sort(null);
        String med = lat.isEmpty() ? "-" : String.valueOf(lat.get(lat.size() / 2));
        String name = L == 1 ? "direct (L=1)" : L == 255 ? "epidemic(~L=255)" : "spray&wait L=" + L;
        System.out.printf("%-16s %8.0f%% %8.0f%% %7.0f%%  %14s  %19.1f  %15d%n", name, 100.0 * d10 / msgs, 100.0 * d60 / msgs,
                100.0 * d6h / msgs, med + (lat.size() < msgs ? "*" : ""), copySamples / samples, transfers);
    }
}
