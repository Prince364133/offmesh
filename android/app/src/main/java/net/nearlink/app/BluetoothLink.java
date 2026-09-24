package net.nearlink.app;

import android.annotation.SuppressLint;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothServerSocket;
import android.bluetooth.BluetoothSocket;
import android.content.Context;
import android.content.SharedPreferences;

import java.io.IOException;
import java.util.HashSet;
import java.util.Set;
import java.util.UUID;

import net.nearlink.core.SyncSession;

/**
 * Bluetooth Classic RFCOMM transport (AOSP API, no Google Play services).
 * Uses "insecure" RFCOMM (no Bluetooth-level authentication): all confidentiality
 * and authenticity come from the end-to-end sealed bundles and signed receipts.
 *
 * Callers must hold BLUETOOTH_CONNECT (and BLUETOOTH_SCAN for discovery).
 */
@SuppressLint("MissingPermission")
public final class BluetoothLink {
    public static final UUID SERVICE_UUID = UUID.fromString("6e4c0001-3b1f-4c1e-9a55-7f2d1c0de001");
    private static final String PREFS = "bt_peers";
    private final Context ctx;
    private final BluetoothAdapter adapter;
    private volatile BluetoothServerSocket server;
    private volatile boolean running;

    public BluetoothLink(Context ctx) {
        this.ctx = ctx.getApplicationContext();
        BluetoothManager bm = (BluetoothManager) ctx.getSystemService(Context.BLUETOOTH_SERVICE);
        this.adapter = bm == null ? null : bm.getAdapter();
    }

    public boolean available() { return adapter != null; }
    public boolean enabled() { return adapter != null && adapter.isEnabled(); }
    public BluetoothAdapter adapter() { return adapter; }

    /** Accept loop: every inbound connection runs one sync session. */
    public void startServer() {
        if (running || !enabled()) return;
        running = true;
        Thread t = new Thread(() -> {
            while (running) {
                try {
                    server = adapter.listenUsingInsecureRfcommWithServiceRecord("NearLink", SERVICE_UUID);
                    BluetoothSocket s = server.accept();
                    server.close();
                    String addr = s.getRemoteDevice().getAddress();
                    new Thread(() -> runSession(s, addr, "BT in"), "nl-bt-session").start();
                } catch (IOException e) {
                    if (!running) return;
                    App.get().event("BT server error: " + e.getMessage());
                    try { Thread.sleep(3000); } catch (InterruptedException ie) { return; }
                }
            }
        }, "nl-bt-accept");
        t.setDaemon(true);
        t.start();
    }

    public void stopServer() {
        running = false;
        try { if (server != null) server.close(); } catch (IOException ignored) {}
    }

    /** Outbound sync to a device (blocking; call off the UI thread). */
    public SyncSession.Result syncWith(BluetoothDevice d) {
        SyncSession.Result fail = new SyncSession.Result();
        if (!enabled()) { fail.error = "Bluetooth off"; return fail; }
        adapter.cancelDiscovery(); // discovery slows/blocks RFCOMM connects
        BluetoothSocket s = null;
        try {
            s = d.createInsecureRfcommSocketToServiceRecord(SERVICE_UUID);
            s.connect();
        } catch (IOException e) {
            try { if (s != null) s.close(); } catch (IOException ignored) {}
            fail.error = "connect failed: " + e.getMessage();
            return fail;
        }
        return runSession(s, d.getAddress(), "BT out");
    }

    private SyncSession.Result runSession(BluetoothSocket s, String addr, String dir) {
        long t0 = System.currentTimeMillis();
        SyncSession.Result r;
        try (BluetoothSocket sock = s) {
            r = new SyncSession(App.get().node(), sock.getInputStream(), sock.getOutputStream(), 30_000).run();
        } catch (IOException e) {
            r = new SyncSession.Result(); r.error = e.toString();
        }
        if (r.peerId != null) remember(addr);
        App.get().event(dir + " " + addr + " (" + (System.currentTimeMillis() - t0) + " ms): " + r);
        return r;
    }

    // -------- remembered peers: devices we have synced with before (for background retries) --------
    public synchronized void remember(String addr) {
        SharedPreferences p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        Set<String> s = new HashSet<>(p.getStringSet("addrs", new HashSet<>()));
        if (s.add(addr)) p.edit().putStringSet("addrs", s).apply();
    }
    public synchronized Set<String> remembered() {
        return new HashSet<>(ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getStringSet("addrs", new HashSet<>()));
    }
    public BluetoothDevice device(String addr) { return adapter.getRemoteDevice(addr); }
}
