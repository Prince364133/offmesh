package net.nearlink.core;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;

/** Persistence for the node's whole state blob. */
public interface Store {
    byte[] load() throws IOException;   // null if nothing saved yet
    void save(byte[] data) throws IOException;

    final class Memory implements Store {
        private byte[] data;
        public synchronized byte[] load() { return data == null ? null : data.clone(); }
        public synchronized void save(byte[] d) { data = d.clone(); }
    }

    /** Atomic file store: write temp file, fsync, rename over the old one (crash-safe on POSIX/ext4/f2fs). */
    final class FileStore implements Store {
        private final File file;
        public FileStore(File file) { this.file = file; }
        public synchronized byte[] load() throws IOException {
            return file.exists() ? Files.readAllBytes(file.toPath()) : null;
        }
        public synchronized void save(byte[] d) throws IOException {
            File tmp = new File(file.getPath() + ".tmp");
            try (FileOutputStream fos = new FileOutputStream(tmp)) { fos.write(d); fos.getFD().sync(); }
            Files.move(tmp.toPath(), file.toPath(), StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        }
    }
}
