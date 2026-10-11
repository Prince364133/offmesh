package net.nearlink.core;

import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Base64;

/** Byte helpers plus a bounds-checked reader for parsing untrusted input. */
public final class Bytes {
    private Bytes() {}

    public static byte[] hex(String s) {
        if (s == null || (s.length() & 1) != 0) throw new IllegalArgumentException("hex must have an even length");
        byte[] out = new byte[s.length() / 2];
        for (int i = 0; i < out.length; i++) {
            int hi = Character.digit(s.charAt(2 * i), 16), lo = Character.digit(s.charAt(2 * i + 1), 16);
            if (hi < 0 || lo < 0) throw new IllegalArgumentException("invalid hex");
            out[i] = (byte) ((hi << 4) | lo);
        }
        return out;
    }
    public static String hex(byte[] b) {
        if (b == null) throw new IllegalArgumentException("bytes must not be null");
        StringBuilder sb = new StringBuilder(b.length * 2);
        for (byte x : b) sb.append(String.format("%02x", x & 0xff));
        return sb.toString();
    }
    public static byte[] concat(byte[]... parts) {
        if (parts == null) throw new IllegalArgumentException("parts must not be null");
        long total = 0;
        for (byte[] p : parts) {
            if (p == null) throw new IllegalArgumentException("part must not be null");
            total += p.length;
            if (total > Integer.MAX_VALUE) throw new IllegalArgumentException("result too long");
        }
        int n = (int) total;
        byte[] out = new byte[n]; int o = 0;
        for (byte[] p : parts) { System.arraycopy(p, 0, out, o, p.length); o += p.length; }
        return out;
    }
    public static byte[] slice(byte[] b, int off, int len) {
        if (b == null || off < 0 || len < 0 || len > b.length - off) throw new IllegalArgumentException("invalid slice");
        return Arrays.copyOfRange(b, off, off + len);
    }
    public static byte[] utf8(String s) {
        if (s == null) throw new IllegalArgumentException("text must not be null");
        return s.getBytes(StandardCharsets.UTF_8);
    }
    /** Reject invalid UTF-8 rather than silently replacing malformed text. */
    public static String decodeUtf8(byte[] data) throws MalformedException {
        try {
            return StandardCharsets.UTF_8.newDecoder()
                    .onMalformedInput(java.nio.charset.CodingErrorAction.REPORT)
                    .onUnmappableCharacter(java.nio.charset.CodingErrorAction.REPORT)
                    .decode(java.nio.ByteBuffer.wrap(data)).toString();
        } catch (java.nio.charset.CharacterCodingException e) { throw new MalformedException("invalid UTF-8"); }
    }
    public static void requireLength(byte[] data, int length, String field) {
        if (data == null || data.length != length) throw new IllegalArgumentException(field + " must be " + length + " bytes");
    }
    public static String b64(byte[] b) {
        if (b == null) throw new IllegalArgumentException("bytes must not be null");
        return Base64.getUrlEncoder().withoutPadding().encodeToString(b);
    }
    public static byte[] unb64(String s) {
        if (s == null) throw new IllegalArgumentException("base64 must not be null");
        return Base64.getUrlDecoder().decode(s.trim());
    }
    public static byte[] u64(long v) { byte[] b = new byte[8]; for (int i = 7; i >= 0; i--) { b[i] = (byte) v; v >>>= 8; } return b; }

    /** Small builder so encoders read cleanly. */
    public static final class Out {
        private final ByteArrayOutputStream bos = new ByteArrayOutputStream();
        private final DataOutputStream d = new DataOutputStream(bos);
        public Out bytes(byte[] b) {
            if (b == null) throw new IllegalArgumentException("bytes must not be null");
            try { d.write(b); } catch (IOException e) { throw new IllegalStateException(e); } return this;
        }
        public Out u8(int v) {
            if (v < 0 || v > 0xff) throw new IllegalArgumentException("u8 out of range");
            try { d.writeByte(v); } catch (IOException e) { throw new IllegalStateException(e); } return this;
        }
        public Out u16(int v) {
            if (v < 0 || v > 0xffff) throw new IllegalArgumentException("u16 out of range");
            try { d.writeShort(v); } catch (IOException e) { throw new IllegalStateException(e); } return this;
        }
        public Out u32(int v) {
            if (v < 0) throw new IllegalArgumentException("u32 out of range");
            try { d.writeInt(v); } catch (IOException e) { throw new IllegalStateException(e); } return this;
        }
        public Out u64(long v) {
            if (v < 0) throw new IllegalArgumentException("u64 out of range");
            try { d.writeLong(v); } catch (IOException e) { throw new IllegalStateException(e); } return this;
        }
        public Out var16(byte[] b) { if (b == null || b.length > 0xffff) throw new IllegalArgumentException("too long"); u16(b.length); return bytes(b); }
        public byte[] done() { return bos.toByteArray(); }
    }

    /** Bounds-checked reader: every read throws MalformedException instead of reading past the end. */
    public static final class In {
        private final byte[] b; private int p;
        public In(byte[] b) { if (b == null) throw new IllegalArgumentException("input must not be null"); this.b = b; }
        private void need(int n) throws MalformedException { if (n < 0 || p > b.length || n > b.length - p) throw new MalformedException("truncated"); }
        public byte[] bytes(int n) throws MalformedException { need(n); byte[] r = slice(b, p, n); p += n; return r; }
        public int u8() throws MalformedException { need(1); return b[p++] & 0xff; }
        public int u16() throws MalformedException { need(2); int v = ((b[p] & 0xff) << 8) | (b[p + 1] & 0xff); p += 2; return v; }
        public int u32() throws MalformedException { need(4); int v = 0; for (int i = 0; i < 4; i++) v = (v << 8) | (b[p++] & 0xff); return v; }
        public long u64() throws MalformedException { need(8); long v = 0; for (int i = 0; i < 8; i++) v = (v << 8) | (b[p++] & 0xff); return v; }
        public byte[] var16(int max) throws MalformedException { int n = u16(); if (n > max) throw new MalformedException("field too long"); return bytes(n); }
        public int position() { return p; }
        public void end() throws MalformedException { if (p != b.length) throw new MalformedException("trailing bytes"); }
    }

    public static final class MalformedException extends Exception {
        private static final long serialVersionUID = 1L;
        public MalformedException(String m) { super(m); }
    }
}
