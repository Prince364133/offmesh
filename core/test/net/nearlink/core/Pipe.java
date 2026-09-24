package net.nearlink.core;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

/** In-memory full-duplex link for tests/simulation. Can be told to "break" after N bytes (models radio loss). */
final class Pipe {
    static final class Chan {
        private final byte[] buf = new byte[1 << 20]; private int r, w, n; private boolean closed; private long written; long cutAfter = Long.MAX_VALUE;
        final InputStream in = new InputStream() {
            @Override public int read() throws IOException { byte[] b = new byte[1]; int k = read(b, 0, 1); return k < 0 ? -1 : b[0] & 0xff; }
            @Override public int read(byte[] b, int off, int len) throws IOException {
                synchronized (Chan.this) {
                    while (n == 0 && !closed) { try { Chan.this.wait(); } catch (InterruptedException e) { throw new IOException(e); } }
                    if (n == 0) return -1;
                    int k = Math.min(len, n);
                    for (int i = 0; i < k; i++) { b[off + i] = buf[r]; r = (r + 1) % buf.length; }
                    n -= k; Chan.this.notifyAll(); return k;
                }
            }
        };
        final OutputStream out = new OutputStream() {
            @Override public void write(int x) throws IOException { write(new byte[]{(byte) x}, 0, 1); }
            @Override public void write(byte[] b, int off, int len) throws IOException {
                synchronized (Chan.this) {
                    for (int i = 0; i < len; i++) {
                        if (closed) throw new IOException("link closed");
                        if (written >= cutAfter) { closed = true; Chan.this.notifyAll(); throw new IOException("link cut"); }
                        while (n == buf.length && !closed) { try { Chan.this.wait(); } catch (InterruptedException e) { throw new IOException(e); } }
                        buf[w] = b[off + i]; w = (w + 1) % buf.length; n++; written++;
                    }
                    Chan.this.notifyAll();
                }
            }
        };
        synchronized void close() { closed = true; notifyAll(); }
    }

    final Chan aToB = new Chan(), bToA = new Chan();
    void close() { aToB.close(); bToA.close(); }

    /** Runs a full sync between two nodes; returns [resultA, resultB]. */
    static SyncSession.Result[] sync(Node a, Node b) { return sync(a, b, Long.MAX_VALUE); }

    static SyncSession.Result[] sync(Node a, Node b, long cutAfterBytes) {
        Pipe p = new Pipe();
        p.aToB.cutAfter = cutAfterBytes;
        SyncSession.Result[] res = new SyncSession.Result[2];
        Thread tb = new Thread(() -> { res[1] = new SyncSession(b, p.aToB.in, p.bToA.out, 5000).run(); p.bToA.close(); });
        tb.start();
        res[0] = new SyncSession(a, p.bToA.in, p.aToB.out, 5000).run();
        p.aToB.close();
        try { tb.join(10000); } catch (InterruptedException ignored) {}
        p.close();
        return res;
    }
}
