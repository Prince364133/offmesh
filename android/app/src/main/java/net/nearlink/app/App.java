package net.nearlink.app;

import android.app.Application;
import android.util.Log;

import java.io.File;
import java.nio.file.Files;
import java.security.Provider;
import java.security.Security;
import java.util.ArrayList;
import java.util.List;

import net.nearlink.core.Crypto;
import net.nearlink.core.Identity;
import net.nearlink.core.Node;
import net.nearlink.core.Store;

/** Process-wide singleton holding the message engine. */
public final class App extends Application {
    static final String TAG = "NearLink";
    private static App instance;
    private Node node;
    private String cryptoStatus = "not run";
    private final List<String> events = new ArrayList<>();

    public static App get() { return instance; }

    @Override public void onCreate() {
        super.onCreate();
        instance = this;
        initCrypto();
        try {
            File idFile = new File(getFilesDir(), "identity.bin");
            Identity me;
            if (idFile.exists()) me = Identity.importPrivate(Files.readAllBytes(idFile.toPath()));
            else {
                String model = android.os.Build.MODEL == null ? "phone" : android.os.Build.MODEL;
                me = Identity.generate(model);
                new Store.FileStore(idFile).save(me.exportPrivate());
            }
            node = new Node(me, new Store.FileStore(new File(getFilesDir(), "state.bin")), System::currentTimeMillis, new Node.Config());
        } catch (Exception e) {
            Log.e(TAG, "startup failed", e);
            event("STARTUP FAILED: " + e);
        }
    }

    /** Platform first; if it lacks Ed25519/X25519/ChaCha20-Poly1305, fall back to bundled BouncyCastle. */
    private void initCrypto() {
        String platform = Crypto.selfTest();
        if ("OK".equals(platform)) { cryptoStatus = "OK (platform provider)"; return; }
        try {
            Provider bc = (Provider) Class.forName("org.bouncycastle.jce.provider.BouncyCastleProvider").getDeclaredConstructor().newInstance();
            Security.removeProvider("BC");
            Security.insertProviderAt(bc, 1);
            Crypto.useProvider(bc);
            String r = Crypto.selfTest();
            cryptoStatus = ("OK".equals(r) ? "OK (BouncyCastle)" : "BROKEN: " + r) + "; platform said: " + platform;
        } catch (Throwable t) {
            cryptoStatus = "BROKEN: platform " + platform + "; BouncyCastle unavailable: " + t;
        }
        Log.i(TAG, "crypto: " + cryptoStatus);
    }

    public Node node() { return node; }
    public String cryptoStatus() { return cryptoStatus; }

    public synchronized void event(String s) {
        String line = android.text.format.DateFormat.format("HH:mm:ss", System.currentTimeMillis()) + "  " + s;
        events.add(0, line);
        while (events.size() > 200) events.remove(events.size() - 1);
        Log.i(TAG, s);
    }
    public synchronized List<String> events() { return new ArrayList<>(events); }
}
