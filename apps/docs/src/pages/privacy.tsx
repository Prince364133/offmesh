import React from 'react';
import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';
import styles from './compliance.module.css';

export default function PrivacyPolicy(): ReactNode {
  return (
    <Layout
      title="Privacy Policy — OffMesh"
      description="Official Privacy Policy for OffMesh by Simplicion Private Limited. Explaining our zero-knowledge architecture, local cryptographic key storage, and store-and-forward privacy.">
      <div className={styles.complianceContainer}>
        <header className={styles.complianceHeader}>
          <span className={styles.complianceBadge}>Official Policy</span>
          <Heading as="h1" className={styles.complianceTitle}>
            Privacy Policy
          </Heading>
          <p style={{ color: 'var(--offmesh-text-secondary)', margin: 0 }}>
            Simplicion Private Limited (&quot;we&quot;, &quot;our&quot;, or &quot;us&quot;) operates the OffMesh mobile application (Package: <code>net.offmesh.app</code>) and decentralized mesh communication infrastructure. We are committed to absolute user privacy, zero-knowledge cryptographic security, and transparency.
          </p>

          <div className={styles.complianceMetaGrid}>
            <div>
              <div className={styles.complianceMetaLabel}>Legal Entity</div>
              <div className={styles.complianceMetaValue}>Simplicion Private Limited</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>App Identifier</div>
              <div className={styles.complianceMetaValue}>net.offmesh.app</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>Effective Date</div>
              <div className={styles.complianceMetaValue}>September 24, 2026</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>Developer Contact</div>
              <div className={styles.complianceMetaValue}>simplicion.com@gmail.com</div>
            </div>
          </div>
        </header>

        <main className={styles.complianceContent}>
          <div className={styles.calloutBox}>
            <strong>Core Privacy Guarantee:</strong> OffMesh is an offline-first, decentralized delay-tolerant messaging platform. We do not require, collect, or store your phone number, email address, real name, address book, or personal identity. All messages are protected with end-to-end encryption (E2EE) using cryptographic keys generated and stored exclusively on your physical device. Intermediate relays and central gateways can never read your messages.
          </div>

          <h2>1. Information We Do NOT Collect</h2>
          <p>
            Unlike conventional messaging applications, OffMesh is engineered specifically to eliminate data harvesting. We strictly do not collect:
          </p>
          <ul>
            <li><strong>No Personal Identifiers:</strong> We do not ask for or store phone numbers, email addresses, usernames, real names, or national identification numbers.</li>
            <li><strong>No Address Book Scraping:</strong> OffMesh never uploads, reads, or transmits your device contacts or phone directory.</li>
            <li><strong>No Location Tracking:</strong> We never log, track, record, or transmit your device GPS coordinates to any server.</li>
            <li><strong>No Behavioral Analytics or Trackers:</strong> We include <strong>zero</strong> advertising networks, third-party trackers, or behavioral analytics SDKs (no Google Firebase Analytics, no Facebook SDK, no AppsFlyer).</li>
          </ul>

          <h2>2. How Data is Processed &amp; Stored</h2>
          <h3>2.1 Cryptographic Identity</h3>
          <p>
            When you launch OffMesh, your device generates an Ed25519 identity keypair and a Curve25519 encryption keypair. These keys are stored locally on your device within the secure hardware enclave (Android KeyStore / Secure Element). Your private keys never leave your physical hardware.
          </p>

          <h3>2.2 End-to-End Encryption (E2EE)</h3>
          <p>
            All messages, text, media, and metadata envelopes are encrypted end-to-end using <strong>Curve25519 ECDH key agreement</strong> and <strong>ChaCha20-Poly1305 AEAD</strong> authenticated encryption. Only the intended recipient holding the matching private key can decrypt the content.
          </p>

          <h3>2.3 Opportunistic Mesh Relaying</h3>
          <p>
            In offline environments, encrypted bundles are transferred between devices over Bluetooth Low Energy (BLE) and Wi-Fi Direct using store-carry-forward delay-tolerant routing. Intermediate relay phones receive only sealed, opaque binary bundles. Relay devices cannot inspect, read, alter, or forge message payloads.
          </p>

          <h3>2.4 Cloud Gateway Buffer</h3>
          <p>
            When an intermediate relay or device connects to the internet, it may upload sealed packets to our Cloud Gateway to assist delivery to recipients who are not physically nearby. The Cloud Gateway acts purely as a temporary, blind store-and-forward mailbox:
          </p>
          <ul>
            <li>The gateway stores only encrypted blobs, ephemeral routing hashes, and expiry timestamps (TTL).</li>
            <li>Packets automatically expire and are <strong>permanently deleted</strong> upon recipient acknowledgment or after the TTL expires (default 7 days).</li>
          </ul>

          <h2>3. Operating System Permissions</h2>
          <p>
            OffMesh requests only the minimum Android runtime permissions necessary to discover nearby physical peers and transmit mesh packets:
          </p>

          <table className={styles.complianceTable}>
            <thead>
              <tr>
                <th>Permission</th>
                <th>Purpose</th>
                <th>Data Collected / Stored</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><code>BLUETOOTH_SCAN</code><br /><code>BLUETOOTH_ADVERTISE</code><br /><code>BLUETOOTH_CONNECT</code></td>
                <td>Discovers nearby OffMesh smartphones and establishes direct radio links for packet transfer.</td>
                <td>None. Ephemeral peer identifiers are kept in volatile memory only during active radio connection.</td>
              </tr>
              <tr>
                <td><code>ACCESS_FINE_LOCATION</code><br /><code>NEARBY_WIFI_DEVICES</code></td>
                <td>Mandated by Android OS to scan for local Bluetooth Low Energy and Wi-Fi Direct beacons.</td>
                <td>None. OffMesh does <strong>not</strong> access or transmit your geographical coordinates.</td>
              </tr>
              <tr>
                <td><code>POST_NOTIFICATIONS</code></td>
                <td>Alerts you when a message arrives from a contact or peer.</td>
                <td>None. Handled entirely on-device by local operating system notification managers.</td>
              </tr>
              <tr>
                <td><code>CAMERA</code> (Optional)</td>
                <td>Allows you to scan a friend&apos;s physical QR contact card to exchange public keys.</td>
                <td>None. Images are parsed in memory locally and discarded immediately. No photos or video are saved or transmitted.</td>
              </tr>
            </tbody>
          </table>

          <h2>4. Data Retention and Deletion</h2>
          <p>
            You retain absolute sovereignty over your communication data:
          </p>
          <ul>
            <li><strong>Local Device Wipe:</strong> You can purge all conversations, message history, cached bundles, and cryptographic identity keys at any time via <strong>Settings &gt; Storage &amp; Data &gt; Wipe All Keys &amp; Data</strong>. Once confirmed, keys are permanently purged from hardware storage.</li>
            <li><strong>Gateway Buffer Expiration:</strong> Sealed packets held in the gateway buffer are automatically deleted when an authenticated anti-packet receipt is validated, or when the message TTL expires.</li>
            <li>For comprehensive account and data deletion instructions, visit our dedicated <Link to="/deletion">Account &amp; Data Deletion Guide</Link>.</li>
          </ul>

          <h2>5. Children&apos;s Privacy</h2>
          <p>
            OffMesh is not directed toward children under the age of 13. Because OffMesh does not collect names, emails, ages, or any personal information, we do not knowingly collect or solicit data from children under 13.
          </p>

          <h2>6. Compliance with International Laws</h2>
          <p>
            OffMesh is designed from inception to meet and exceed global privacy and data protection standards:
          </p>
          <ul>
            <li><strong>Digital Personal Data Protection Act, 2023 (India):</strong> Zero personal data harvesting, purpose limitation, and self-service local deletion.</li>
            <li><strong>General Data Protection Regulation (GDPR / EU):</strong> Data minimization (Article 5), privacy by design and by default (Article 25), and zero third-party cross-border transfers.</li>
            <li><strong>California Consumer Privacy Act (CCPA / CPRA):</strong> We do not sell, share, or monetize any personal information.</li>
          </ul>

          <h2>7. Contact and Data Protection Officer</h2>
          <p>
            If you have questions, inquiries, or requests regarding this Privacy Policy or our security practices, please contact our Data Protection Officer:
          </p>
          <div className={styles.calloutBox}>
            <strong>Simplicion Private Limited</strong><br />
            Attn: Privacy &amp; Compliance Team<br />
            Address: Dpt 808b F-79&amp;80 Dlf Prime Tower, Okhla Industrial Area Phase-i, New Delhi - 110020, India<br />
            Email: <a href="mailto:simplicion.com@gmail.com">simplicion.com@gmail.com</a><br />
            Website: <a href="https://simplicion.com/" target="_blank" rel="noopener noreferrer">https://simplicion.com/</a>
          </div>

          <div className={styles.complianceFooterBox}>
            <Link to="/" className="button button--secondary button--sm">
              ← Return to OffMesh Overview
            </Link>
            <div style={{ display: 'flex', gap: '8px' }}>
              <Link to="/terms" className="button button--secondary button--sm">
                Terms of Service
              </Link>
              <Link to="/data-safety" className="button button--secondary button--sm">
                Data Safety
              </Link>
              <Link to="/deletion" className="button button--secondary button--sm">
                Data Deletion
              </Link>
            </div>
          </div>
        </main>
      </div>
    </Layout>
  );
}
