package net.nearlink.app;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.IBinder;

import net.nearlink.core.Node;
import net.nearlink.core.SyncSession;
import net.nearlink.core.TcpTransport;

/**
 * Foreground service (type connectedDevice) that keeps the Bluetooth and TCP listeners
 * open and periodically retries remembered Bluetooth peers so queued messages move
 * without the user pressing anything. Whether this survives Doze / OEM battery
 * managers on real phones is UNTESTED (see EXPERIMENT_LOG.md).
 */
public final class MeshService extends Service {
    static final String CHANNEL = "mesh";
    static final long RETRY_MS = 90_000;
    private BluetoothLink bt;
    private TcpTransport tcp;
    private volatile boolean running;

    @Override public void onCreate() {
        super.onCreate();
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel(CHANNEL, "Offline messaging", NotificationManager.IMPORTANCE_LOW));
    }

    @Override public int onStartCommand(Intent intent, int flags, int startId) {
        Notification n = new Notification.Builder(this, CHANNEL)
                .setContentTitle("NearLink is carrying messages")
                .setContentText("Listening on Bluetooth and local Wi-Fi; no internet used")
                .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
                .setOngoing(true).build();
        startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE);
        if (!running) start();
        return START_STICKY;
    }

    private void start() {
        running = true;
        Node node = App.get().node();
        bt = new BluetoothLink(this);
        if (bt.enabled()) bt.startServer(); else App.get().event("Bluetooth is off: BT transport idle");
        tcp = new TcpTransport(node);
        try {
            int port = tcp.listen(TcpTransport.DEFAULT_PORT, r -> App.get().event("LAN in: " + r));
            App.get().event("LAN listener on port " + port);
        } catch (Exception e) { App.get().event("LAN listener failed: " + e.getMessage()); }

        Thread loop = new Thread(() -> {
            while (running) {
                try {
                    node.sweep();
                    if (bt.enabled()) {
                        bt.startServer();
                        for (String addr : bt.remembered()) {
                            if (!running) break;
                            SyncSession.Result r = bt.syncWith(bt.device(addr));
                            if (r.error != null && r.error.startsWith("connect failed")) continue; // peer not in range: normal
                        }
                    }
                    Thread.sleep(RETRY_MS);
                } catch (InterruptedException e) { return; }
                catch (Exception e) { App.get().event("retry loop: " + e); }
            }
        }, "nl-retry");
        loop.setDaemon(true);
        loop.start();
    }

    @Override public void onDestroy() {
        running = false;
        if (bt != null) bt.stopServer();
        if (tcp != null) tcp.close();
        super.onDestroy();
    }

    @Override public IBinder onBind(Intent intent) { return null; }
}
