package net.nearlink.core;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.function.Consumer;

/**
 * TCP transport for local networks with NO internet: a phone's Wi-Fi hotspot,
 * a Wi-Fi Direct group, or any LAN. Also used for loopback experiments.
 * (Plain TCP; confidentiality comes from end-to-end sealing of bundles.)
 */
public final class TcpTransport {
    public static final int DEFAULT_PORT = 47700;
    private final Node node;
    private ServerSocket server;
    private volatile boolean running;

    public TcpTransport(Node node) { this.node = node; }

    public int listen(int port, Consumer<SyncSession.Result> onResult) throws IOException {
        server = new ServerSocket();
        server.setReuseAddress(true);
        server.bind(new InetSocketAddress(port));
        running = true;
        Thread t = new Thread(() -> {
            while (running) {
                try {
                    Socket s = server.accept();
                    new Thread(() -> onResult.accept(handle(s)), "nl-tcp-session").start();
                } catch (IOException e) { if (!running) return; }
            }
        }, "nl-tcp-accept");
        t.setDaemon(true);
        t.start();
        return server.getLocalPort();
    }

    public SyncSession.Result connect(String host, int port, int timeoutMs) throws IOException {
        Socket s = new Socket();
        s.connect(new InetSocketAddress(host, port), timeoutMs);
        return handle(s);
    }

    private SyncSession.Result handle(Socket s) {
        try (Socket sock = s) {
            sock.setSoTimeout(60_000);
            sock.setTcpNoDelay(true);
            return new SyncSession(node, sock.getInputStream(), sock.getOutputStream(), 30_000).run();
        } catch (IOException e) {
            SyncSession.Result r = new SyncSession.Result(); r.error = e.toString(); return r;
        }
    }

    public void close() { running = false; try { if (server != null) server.close(); } catch (IOException ignored) {} }
}
