package net.nearlink.core;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Empirical Experiment: Opportunistic Mesh-to-Internet Gateway & Anti-Packet (Receipt) Pruning.
 *
 * Validates the exact multi-device scenario:
 * 1. User A sends message M to remote User B (offline, 100km away).
 * 2. User A encounters companions C and D (offline). Bundles are replicated to C and D.
 * 3. User C encounters companion E (offline) and replicates M to E.
 *    -> At this stage, A, C, D, and E all hold bundle M in their relay queues.
 * 4. User D encounters an Internet Gateway / Server S and uploads bundle M.
 * 5. User B connects to Server S, receives M into inbox, and issues a cryptographic signed Receipt R_M.
 * 6. Server S accepts R_M and purges M.
 * 7. User D syncs with Server S, receives R_M, and purges M from its held queue.
 * 8. User D encounters User C offline, syncs R_M, and C purges M.
 * 9. User C encounters User E offline, syncs R_M, and E purges M.
 * 10. User E encounters User A offline, syncs R_M, and A marks M as DELIVERED and purges M.
 * 11. Verification: All nodes hold 0 remaining relay bundles. Re-injection is rejected as duplicate.
 */
public final class MeshPruningExperiment {

    public static void main(String[] args) throws Exception {
        System.out.println("=== NearLink Opportunistic Mesh Pruning & Anti-Packet Experiment ===");

        AtomicLong clock = new AtomicLong(1_700_000_000_000L);
        Node.Config cfg = new Node.Config();
        cfg.initialCopies = 8;
        cfg.hopLimit = 16;
        cfg.acceptFromStrangers = true;

        // Instantiate nodes
        Node nodeA = new Node(Identity.generate("User_A"), new Store.Memory(), clock::get, cfg);
        Node nodeB = new Node(Identity.generate("User_B"), new Store.Memory(), clock::get, cfg);
        Node nodeC = new Node(Identity.generate("Companion_C"), new Store.Memory(), clock::get, cfg);
        Node nodeD = new Node(Identity.generate("Companion_D"), new Store.Memory(), clock::get, cfg);
        Node nodeE = new Node(Identity.generate("Companion_E"), new Store.Memory(), clock::get, cfg);
        Node serverS = new Node(Identity.generate("InternetServer_S"), new Store.Memory(), clock::get, cfg);

        // Pre-establish contacts between sender and recipient
        nodeA.addContact(nodeB.me.asContact());
        nodeB.addContact(nodeA.me.asContact());

        // Step 1: User A composes message for User B (offline, 100km away)
        String msgId = nodeA.send(nodeB.idHex(), "Important notice from village A to B");
        System.out.printf("[Step 1] User A queued msg %s. Status: %s. A held=%d%n",
                msgId.substring(0, 8), nodeA.outgoing(msgId).status, nodeA.relayCount());

        // Step 2: User A encounters companions C and D offline
        Pipe.sync(nodeA, nodeC);
        Pipe.sync(nodeA, nodeD);
        System.out.printf("[Step 2] A met C and D offline. Held bundles -> C: %d, D: %d%n",
                nodeC.relayCount(), nodeD.relayCount());
        assert nodeC.relayCount() == 1 : "Node C should hold 1 relay bundle";
        assert nodeD.relayCount() == 1 : "Node D should hold 1 relay bundle";

        // Step 3: Companion C encounters Companion E offline
        Pipe.sync(nodeC, nodeE);
        System.out.printf("[Step 3] C met E offline. Held bundles -> E: %d%n", nodeE.relayCount());
        assert nodeE.relayCount() == 1 : "Node E should hold 1 relay bundle";

        // At this point, A, C, D, E all hold copies of M.
        System.out.printf("   Current held copies across mesh: A=%d, C=%d, D=%d, E=%d%n",
                nodeA.relayCount(), nodeC.relayCount(), nodeD.relayCount(), nodeE.relayCount());

        // Step 4: Companion D encounters Internet Server S (e.g. reaches cellular coverage)
        Pipe.sync(nodeD, serverS);
        System.out.printf("[Step 4] D uploaded bundle to Server S. Server S held: %d%n", serverS.relayCount());
        assert serverS.relayCount() == 1 : "Server S should hold 1 bundle for B";

        // Step 5: User B connects to Internet Server S (comes online)
        Pipe.sync(serverS, nodeB);
        System.out.printf("[Step 5] User B synced with Server S. B inbox count: %d%n", nodeB.inbox().size());
        assert nodeB.inbox().size() == 1 : "User B must receive 1 message in inbox";
        assert nodeB.inbox().get(0).text.equals("Important notice from village A to B");

        // When B received the message, B generated a cryptographic signed receipt R_M.
        // Server S accepted R_M during the sync. Let's verify Server S purged M:
        System.out.printf("   Server S after delivery: held=%d, receipts=%d%n",
                serverS.relayCount(), serverS.receipts().size());
        assert serverS.relayCount() == 0 : "Server S must have purged bundle upon receiving receipt!";

        // Step 6: Companion D reconnects with Server S
        Pipe.sync(nodeD, serverS);
        System.out.printf("[Step 6] D synced with Server S. D held: %d, D receipts: %d%n",
                nodeD.relayCount(), nodeD.receipts().size());
        assert nodeD.relayCount() == 0 : "Node D must have purged bundle upon receiving receipt!";
        assert nodeD.receipts().size() == 1 : "Node D must have accepted the signed receipt";

        // Step 7: Companion D returns to the offline village and meets Companion C
        Pipe.sync(nodeD, nodeC);
        System.out.printf("[Step 7] D met C offline. C held: %d, C receipts: %d%n",
                nodeC.relayCount(), nodeC.receipts().size());
        assert nodeC.relayCount() == 0 : "Node C must have purged bundle upon receiving receipt from D!";

        // Step 8: Companion C meets Companion E offline
        Pipe.sync(nodeC, nodeE);
        System.out.printf("[Step 8] C met E offline. E held: %d, E receipts: %d%n",
                nodeE.relayCount(), nodeE.receipts().size());
        assert nodeE.relayCount() == 0 : "Node E must have purged bundle upon receiving receipt from C!";

        // Step 9: Companion E meets original Sender User A offline
        Pipe.sync(nodeE, nodeA);
        System.out.printf("[Step 9] E met A offline. A held: %d, A status: %s%n",
                nodeA.relayCount(), nodeA.outgoing(msgId).status);
        assert nodeA.relayCount() == 0 : "Node A must have purged bundle upon receiving receipt from E!";
        assert nodeA.outgoing(msgId).status == Node.Status.DELIVERED : "Node A outgoing status must be DELIVERED!";

        // Step 10: Verify total network state
        System.out.println();
        System.out.println("=== Network-wide State Summary ===");
        System.out.printf("Node A: held=%d, receipts=%d, outgoing_status=%s%n",
                nodeA.relayCount(), nodeA.receipts().size(), nodeA.outgoing(msgId).status);
        System.out.printf("Node C: held=%d, receipts=%d%n", nodeC.relayCount(), nodeC.receipts().size());
        System.out.printf("Node D: held=%d, receipts=%d%n", nodeD.relayCount(), nodeD.receipts().size());
        System.out.printf("Node E: held=%d, receipts=%d%n", nodeE.relayCount(), nodeE.receipts().size());
        System.out.printf("Server: held=%d, receipts=%d%n", serverS.relayCount(), serverS.receipts().size());
        System.out.printf("Node B: inbox=%d, receipts=%d%n", nodeB.inbox().size(), nodeB.receipts().size());

        // Step 11: Attempt re-injection or duplicate forwarding
        System.out.println();
        System.out.println("[Step 11] Testing re-injection of the same message into Node C...");
        SyncSession.Result[] reAttempt = Pipe.sync(nodeA, nodeC);
        System.out.printf("Re-sync between A and C: bundlesSent=[%d, %d], receiptsSent=[%d, %d]%n",
                reAttempt[0].bundlesSent, reAttempt[1].bundlesSent,
                reAttempt[0].receiptsOut, reAttempt[1].receiptsOut);
        assert reAttempt[0].bundlesSent == 0 && reAttempt[1].bundlesSent == 0 : "Zero bundles sent on re-sync";

        System.out.println();
        System.out.println(">>> EXPERIMENT PASSED: All 17/N mesh forwarding jobs terminated cleanly via signed receipts! <<<");
    }
}
