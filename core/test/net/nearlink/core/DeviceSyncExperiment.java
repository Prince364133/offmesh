package net.nearlink.core;

import java.io.File;

/**
 * Physical/Emulator integration experiment:
 * Connects from host workstation over TCP (port 47700) to the running NearLink Android app.
 */
public final class DeviceSyncExperiment {
    public static void main(String[] args) throws Exception {
        System.out.println("=== NearLink Host-to-Android Device Integration Experiment ===");
        
        // 1. Host Workstation Identity & Node
        File stateFile = new File("build/host_state.bin");
        Identity hostIdentity;
        File idFile = new File("build/host_identity.bin");
        if (idFile.exists()) {
            hostIdentity = Identity.importPrivate(java.nio.file.Files.readAllBytes(idFile.toPath()));
        } else {
            hostIdentity = Identity.generate("HostWorkstation");
            java.nio.file.Files.write(idFile.toPath(), hostIdentity.exportPrivate());
        }
        
        Node hostNode = new Node(hostIdentity, new Store.FileStore(stateFile), System::currentTimeMillis, new Node.Config());
        
        System.out.println("Host Identity: " + hostIdentity.name);
        System.out.println("Host Address:  " + hostNode.idHex());
        System.out.println("Host Card:     " + hostIdentity.card());
        System.out.println();

        // 2. Phone Card from emulator
        String phoneCard = args.length > 0 ? args[0] : "NL1:ABNzZGtfZ3Bob25lNjRfeDg2XzY0DH8JpNhaH0QHWuVMbBLs1EJ_9klueS-pd32wQVuBAoPLV8B8CWOYxWWdZn6W2Jg1TKzKONZ0lNAsVg3OtQ05Qw";
        Contact phoneContact = Contact.parseCard(phoneCard);
        hostNode.addContact(phoneContact);
        System.out.println("Added Phone Contact: " + phoneContact.name + " (" + phoneContact.idHex() + ")");
        System.out.println("Safety code: " + Contact.safetyCode(hostNode.me.id, phoneContact.id));
        System.out.println();

        // 3. Compose and queue an offline encrypted message
        String msgText = "Hello Android! This is an offline encrypted message from HostWorkstation.";
        String msgId = hostNode.send(phoneContact.idHex(), msgText);
        System.out.println("Queued outgoing message: " + msgId);
        System.out.println("Pre-sync Status: " + hostNode.outgoing(msgId).describe());
        System.out.println();

        // 4. Connect to Android app on port 47700 via TcpTransport
        System.out.println("Connecting to Android App on 127.0.0.1:47700...");
        TcpTransport transport = new TcpTransport(hostNode);
        SyncSession.Result result = transport.connect("127.0.0.1", 47700, 5000);
        
        System.out.println("SyncSession result: " + result);
        System.out.println();

        // 5. Check delivery status & receipt
        Node.Outgoing out = hostNode.outgoing(msgId);
        System.out.println("Post-sync Status: " + out.status);
        System.out.println("Status description: " + out.describe());
        if (out.status == Node.Status.DELIVERED) {
            System.out.println("SUCCESS: Message verified delivered and signed receipt accepted from Android device!");
        } else {
            System.out.println("Message not yet confirmed delivered. Status: " + out.status);
        }
        System.out.println();
        System.out.println("Host Inbox (" + hostNode.inbox().size() + " messages):");
        for (Node.Incoming inc : hostNode.inbox()) {
            System.out.println("  <- From " + inc.fromId.substring(0, 8) + ": \"" + inc.text + "\" [sent: " + inc.sentAt + ", recv: " + inc.receivedAt + "]");
        }
        System.out.println("Experiment complete.");
    }
}

