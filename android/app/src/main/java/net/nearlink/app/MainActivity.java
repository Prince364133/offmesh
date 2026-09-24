package net.nearlink.app;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.content.BroadcastReceiver;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.InputType;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.ScrollView;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;

import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Date;
import java.util.List;
import java.util.Locale;

import net.nearlink.core.Contact;
import net.nearlink.core.Node;
import net.nearlink.core.SyncSession;
import net.nearlink.core.TcpTransport;

/**
 * Deliberately plain, single-screen test UI (no AndroidX) for the Stage 2-4 experiments.
 * Not a product UI.
 */
@SuppressLint("MissingPermission")
public final class MainActivity extends Activity {
    private final Handler ui = new Handler(Looper.getMainLooper());
    private BluetoothLink bt;
    private TextView status, myCard;
    private EditText pasteCard, messageText, lanHost;
    private Spinner contactSpinner;
    private final List<BluetoothDevice> found = new ArrayList<>();
    private ArrayAdapter<String> foundAdapter, feedAdapter;
    private final List<Contact> contactList = new ArrayList<>();
    private final SimpleDateFormat fmt = new SimpleDateFormat("HH:mm:ss", Locale.US);

    private final BroadcastReceiver discovery = new BroadcastReceiver() {
        @Override public void onReceive(Context c, Intent i) {
            if (BluetoothDevice.ACTION_FOUND.equals(i.getAction())) {
                @SuppressWarnings("deprecation") BluetoothDevice d = i.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE); // typed overload is API 33+
                if (d != null && !found.contains(d)) {
                    found.add(d);
                    String name = d.getName();
                    foundAdapter.add((name == null ? "(no name)" : name) + "  " + d.getAddress());
                }
            } else if (BluetoothAdapter.ACTION_DISCOVERY_FINISHED.equals(i.getAction())) {
                App.get().event("Bluetooth scan finished: " + found.size() + " device(s)");
            }
        }
    };

    @Override protected void onCreate(Bundle b) {
        super.onCreate(b);
        bt = new BluetoothLink(this);
        buildUi();
        requestPerms();
        IntentFilter f = new IntentFilter(BluetoothDevice.ACTION_FOUND);
        f.addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED);
        registerReceiver(discovery, f);
        ui.post(refresher);
    }

    @Override protected void onDestroy() { unregisterReceiver(discovery); ui.removeCallbacks(refresher); super.onDestroy(); }

    private void requestPerms() {
        List<String> need = new ArrayList<>();
        for (String p : new String[]{Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.BLUETOOTH_ADVERTISE, Manifest.permission.POST_NOTIFICATIONS})
            if (checkSelfPermission(p) != PackageManager.PERMISSION_GRANTED) need.add(p);
        if (!need.isEmpty()) requestPermissions(need.toArray(new String[0]), 1);
    }

    private boolean hasBtPerms() {
        return checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED
                && checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED;
    }

    // ------------------------------------------------------------------ UI
    private void buildUi() {
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        int pad = (int) (12 * getResources().getDisplayMetrics().density);
        col.setPadding(pad, pad, pad, pad);

        status = text(col, "");
        LinearLayout row1 = row(col);
        button(row1, "Start service", () -> startForegroundService(new Intent(this, MeshService.class)));
        button(row1, "Discoverable", () -> startActivity(new Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE)
                .putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, 300)));
        button(row1, "Scan BT", this::scan);

        text(col, "Nearby Bluetooth devices (tap to sync):");
        foundAdapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, new ArrayList<>());
        ListView foundList = list(col, foundAdapter, 160);
        foundList.setOnItemClickListener((p, v, pos, id) -> syncBt(found.get(pos)));

        text(col, "My contact card (share in person):");
        myCard = text(col, "");
        myCard.setTextIsSelectable(true);
        button(row(col), "Copy my card", () -> {
            ((ClipboardManager) getSystemService(CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("NearLink card", node().me.card()));
            toast("Copied");
        });

        pasteCard = edit(col, "Paste a friend's NL1:... card");
        button(row(col), "Add contact", this::addContact);

        contactSpinner = new Spinner(this);
        col.addView(contactSpinner);
        messageText = edit(col, "Message");
        button(row(col), "Send (queue)", this::send);

        lanHost = edit(col, "Peer IP on same hotspot/Wi-Fi (no internet needed)");
        lanHost.setInputType(InputType.TYPE_CLASS_TEXT);
        button(row(col), "Sync over Wi-Fi/hotspot", this::syncLan);

        text(col, "Messages and events:");
        feedAdapter = new ArrayAdapter<>(this, android.R.layout.simple_list_item_1, new ArrayList<>());
        list(col, feedAdapter, 900);

        ScrollView sv = new ScrollView(this);
        sv.addView(col);
        setContentView(sv);
        reloadContacts();
    }

    private final Runnable refresher = new Runnable() {
        @Override public void run() { refresh(); ui.postDelayed(this, 2000); }
    };

    private void refresh() {
        Node n = node();
        if (n == null) { status.setText("Engine failed to start. Crypto: " + App.get().cryptoStatus()); return; }
        status.setText("Me: " + n.me.name + "  id " + n.idHex().substring(0, 12) + "\nCrypto: " + App.get().cryptoStatus()
                + "\nBluetooth: " + (!bt.available() ? "none" : bt.enabled() ? "on" : "OFF") + "   Relaying for others: " + n.relayCount()
                + "\nLocal IPs: " + localIps());
        myCard.setText(n.me.card());
        List<String> feed = new ArrayList<>();
        List<Object[]> rows = new ArrayList<>();
        for (Node.Outgoing o : n.outgoing()) rows.add(new Object[]{o.created, "-> " + name(o.toId) + ": " + o.text + "\n   [" + o.describe() + "]"});
        for (Node.Incoming i : n.inbox()) rows.add(new Object[]{i.receivedAt, "<- " + name(i.fromId) + ": " + i.text + "\n   [received " + fmt.format(new Date(i.receivedAt))
                + ", sent " + fmt.format(new Date(i.sentAt)) + ", delay " + (i.receivedAt - i.sentAt) / 1000 + " s]"});
        rows.sort((x, y) -> Long.compare((Long) y[0], (Long) x[0]));
        for (Object[] r : rows) feed.add(fmt.format(new Date((Long) r[0])) + " " + r[1]);
        feed.add("---- event log ----");
        feed.addAll(App.get().events());
        feedAdapter.clear(); feedAdapter.addAll(feed);
    }

    // ------------------------------------------------------------------ actions
    private void scan() {
        if (!hasBtPerms()) { requestPerms(); return; }
        if (!bt.enabled()) { toast("Turn Bluetooth on first"); return; }
        found.clear(); foundAdapter.clear();
        boolean ok = bt.adapter().startDiscovery();
        App.get().event("Bluetooth scan started: " + ok);
    }

    private void syncBt(BluetoothDevice d) {
        App.get().event("Syncing with " + d.getAddress() + " ...");
        new Thread(() -> { SyncSession.Result r = bt.syncWith(d); ui.post(() -> toast(r.completed ? "Sync complete" : "Sync failed: " + r.error)); }).start();
    }

    private void syncLan() {
        String host = lanHost.getText().toString().trim();
        if (host.isEmpty()) { toast("Enter peer IP"); return; }
        new Thread(() -> {
            SyncSession.Result r;
            try { r = new TcpTransport(node()).connect(host, TcpTransport.DEFAULT_PORT, 5000); }
            catch (Exception e) { r = new SyncSession.Result(); r.error = e.toString(); }
            App.get().event("LAN out " + host + ": " + r);
            SyncSession.Result fr = r;
            ui.post(() -> toast(fr.completed ? "Sync complete" : "Sync failed: " + fr.error));
        }).start();
    }

    private void addContact() {
        try {
            Contact c = Contact.parseCard(pasteCard.getText().toString());
            node().addContact(c);
            pasteCard.setText("");
            reloadContacts();
            App.get().event("Added contact " + c.name + ". Safety code (compare in person): " + Contact.safetyCode(node().me.id, c.id));
        } catch (Exception e) { toast("Invalid card: " + e.getMessage()); }
    }

    private void send() {
        int pos = contactSpinner.getSelectedItemPosition();
        String text = messageText.getText().toString();
        if (pos < 0 || pos >= contactList.size() || text.isEmpty()) { toast("Pick a contact and type a message"); return; }
        try { node().send(contactList.get(pos).idHex(), text); messageText.setText(""); refresh(); }
        catch (Exception e) { toast("Send failed: " + e.getMessage()); }
    }

    // ------------------------------------------------------------------ helpers
    private Node node() { return App.get().node(); }
    private void reloadContacts() {
        contactList.clear();
        List<String> names = new ArrayList<>();
        if (node() != null) for (Contact c : node().contacts()) { contactList.add(c); names.add(c.name + " (" + c.idHex().substring(0, 8) + ")"); }
        contactSpinner.setAdapter(new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, names));
    }
    private String name(String idHex) { Contact c = node().contact(idHex); return c == null ? idHex.substring(0, 8) : c.name; }
    private static String localIps() {
        StringBuilder sb = new StringBuilder();
        try {
            for (NetworkInterface ni : Collections.list(NetworkInterface.getNetworkInterfaces()))
                for (InetAddress a : Collections.list(ni.getInetAddresses()))
                    if (a instanceof Inet4Address && !a.isLoopbackAddress()) sb.append(ni.getName()).append('=').append(a.getHostAddress()).append(' ');
        } catch (Exception ignored) {}
        return sb.length() == 0 ? "none" : sb.toString();
    }
    private void toast(String s) { Toast.makeText(this, s, Toast.LENGTH_LONG).show(); }
    private TextView text(ViewGroup p, String s) { TextView t = new TextView(this); t.setText(s); p.addView(t); return t; }
    private EditText edit(ViewGroup p, String hint) { EditText e = new EditText(this); e.setHint(hint); p.addView(e); return e; }
    private LinearLayout row(ViewGroup p) { LinearLayout r = new LinearLayout(this); r.setOrientation(LinearLayout.HORIZONTAL); p.addView(r); return r; }
    private void button(ViewGroup p, String label, Runnable r) { Button b = new Button(this); b.setText(label); b.setOnClickListener(v -> r.run()); p.addView(b); }
    private ListView list(ViewGroup p, ArrayAdapter<String> a, int dpHeight) {
        ListView l = new ListView(this); l.setAdapter(a);
        p.addView(l, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (int) (dpHeight * getResources().getDisplayMetrics().density)));
        return l;
    }
}
