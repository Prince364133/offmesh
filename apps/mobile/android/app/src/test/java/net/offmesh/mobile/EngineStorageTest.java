package net.offmesh.mobile;

import java.io.IOException;
import java.util.Arrays;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import net.nearlink.core.Contact;
import net.nearlink.core.Crypto;
import net.nearlink.core.Identity;
import net.nearlink.core.Node;
import net.nearlink.core.Store;
import net.nearlink.core.SyncSession;
import net.nearlink.core.TcpTransport;
import org.bouncycastle.jce.provider.BouncyCastleProvider;
import org.junit.BeforeClass;
import org.junit.Test;
import static org.junit.Assert.*;

/** Local JVM coverage for the Android crypto fallback, storage envelope and real engine. */
public class EngineStorageTest {
    @BeforeClass public static void useAndroidFallback() {
        Crypto.useProvider(new BouncyCastleProvider());
        assertEquals("OK", Crypto.selfTest());
    }

    private static SecretKey key() throws Exception {
        KeyGenerator generator = KeyGenerator.getInstance("AES");
        generator.init(256);
        return generator.generateKey();
    }

    @Test public void uniqueRandomIdentityAndPrivateRestore() throws Exception {
        Identity first = Identity.generate("Same name");
        Identity second = Identity.generate("Same name");
        assertFalse(Arrays.equals(first.id, second.id));
        Identity restored = Identity.importPrivate(first.exportPrivate());
        assertEquals(first.card(), restored.card());
        assertEquals(first.asContact().idHex(), Contact.parseCard(first.card()).idHex());
    }

    @Test public void encryptedEnvelopeUsesFreshIvAndAuthenticatesPurpose() throws Exception {
        SecretKey key = key();
        EncryptedStateCodec codec = new EncryptedStateCodec(key, "identity");
        byte[] plaintext = "private key material".getBytes(java.nio.charset.StandardCharsets.UTF_8);
        byte[] first = codec.encrypt(plaintext), second = codec.encrypt(plaintext);
        assertFalse(Arrays.equals(first, second));
        assertArrayEquals(plaintext, codec.decrypt(first));
        assertThrows(IOException.class, () -> new EncryptedStateCodec(key, "state").decrypt(first));
        assertThrows(IOException.class, () -> new EncryptedStateCodec(key(), "identity").decrypt(first));
        first[first.length - 1] ^= 1;
        assertThrows(IOException.class, () -> codec.decrypt(first));
        assertThrows(IOException.class, () -> codec.decrypt(new byte[31]));
    }

    @Test public void encryptedStateRestoresContactsAndQueuedMessage() throws Exception {
        Identity alice = Identity.generate("Alice"), bob = Identity.generate("Bob");
        EncryptedMemory store = new EncryptedMemory(key(), "state");
        Node node = new Node(alice, store, System::currentTimeMillis, new Node.Config());
        node.addContact(bob.asContact());
        String id = node.send(bob.asContact().idHex(), "Persist across process recreation");
        assertEquals(Node.Status.QUEUED, node.outgoing(id).status);
        Node restored = new Node(Identity.importPrivate(alice.exportPrivate()), store,
                System::currentTimeMillis, new Node.Config());
        assertEquals(1, restored.contacts().size());
        assertTrue(restored.holds(id));
        assertEquals("Persist across process recreation", restored.outgoing(id).text);
        assertEquals(Node.Status.QUEUED, restored.outgoing(id).status);
        store.encoded[store.encoded.length - 1] ^= 1;
        assertThrows(IOException.class, () -> new Node(alice, store, System::currentTimeMillis, new Node.Config()));
    }

    @Test public void actualTcpExchangeDeliversAndRestoresVerifiedReceipt() throws Exception {
        Identity alice = Identity.generate("Alice"), bob = Identity.generate("Bob");
        EncryptedMemory aliceStore = new EncryptedMemory(key(), "alice-state");
        EncryptedMemory bobStore = new EncryptedMemory(key(), "bob-state");
        Node.Config cfg = new Node.Config();
        cfg.maxRelayBundles = 0;
        Node sender = new Node(alice, aliceStore, System::currentTimeMillis, cfg);
        Node receiver = new Node(bob, bobStore, System::currentTimeMillis, cfg);
        sender.addContact(bob.asContact());
        receiver.addContact(alice.asContact());
        String id = sender.send(bob.asContact().idHex(), "Real sealed TCP message");
        TcpTransport listener = new TcpTransport(receiver);
        TcpTransport client = new TcpTransport(sender);
        try {
            int port = listener.listen(0, result -> {});
            SyncSession.Result result = client.connect("127.0.0.1", port, 5000);
            assertNull(result.error);
            assertTrue(result.completed);
            assertEquals(Node.Status.DELIVERED, sender.outgoing(id).status);
            assertEquals(1, receiver.inbox().size());
            assertEquals("Real sealed TCP message", receiver.inbox().get(0).text);
            assertFalse(sender.holds(id));
            Node restored = new Node(alice, aliceStore, System::currentTimeMillis, cfg);
            assertEquals(Node.Status.DELIVERED, restored.outgoing(id).status);
        } finally {
            client.close();
            listener.close();
        }
    }

    private static final class EncryptedMemory implements Store {
        private final EncryptedStateCodec codec;
        private byte[] encoded;
        EncryptedMemory(SecretKey key, String purpose) { codec = new EncryptedStateCodec(key, purpose); }
        public byte[] load() throws IOException { return encoded == null ? null : codec.decrypt(encoded); }
        public void save(byte[] bytes) throws IOException { encoded = codec.encrypt(bytes); }
    }
}
