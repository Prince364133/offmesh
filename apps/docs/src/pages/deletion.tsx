import React from 'react';
import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';
import styles from './compliance.module.css';

export default function AccountDataDeletion(): ReactNode {
  return (
    <Layout
      title="Account & Data Deletion — OffMesh"
      description="Official Account and Data Deletion instructions for OffMesh by Simplicion Private Limited, complying with Google Play Store data deletion policies.">
      <div className={styles.complianceContainer}>
        <header className={styles.complianceHeader}>
          <span className={styles.complianceBadge}>Google Play Policy Compliance</span>
          <Heading as="h1" className={styles.complianceTitle}>
            Account &amp; Data Deletion Policy
          </Heading>
          <p style={{ color: 'var(--offmesh-text-secondary)', margin: 0 }}>
            This page provides comprehensive, transparent instructions on how users of OffMesh (Package: <code>net.offmesh.app</code>) can delete their cryptographic identity, local conversation databases, and any transient network buffers.
          </p>

          <div className={styles.complianceMetaGrid}>
            <div>
              <div className={styles.complianceMetaLabel}>Publisher</div>
              <div className={styles.complianceMetaValue}>Simplicion Private Limited</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>Package Identifier</div>
              <div className={styles.complianceMetaValue}>net.offmesh.app</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>Compliance Target</div>
              <div className={styles.complianceMetaValue}>Google Play Deletion Requirement</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>Support Email</div>
              <div className={styles.complianceMetaValue}>simplicion.com@gmail.com</div>
            </div>
          </div>
        </header>

        <main className={styles.complianceContent}>
          <div className={styles.calloutBox}>
            <strong>Decentralized Architecture Overview:</strong> OffMesh accounts are decentralized cryptographic keypairs (Ed25519 / Curve25519) generated directly on your mobile device. We do not maintain centralized user databases, usernames, passwords, phone numbers, or user profile servers. Consequently, deleting your account means securely destroying your private keys and local data stores, instantly rendering your identity permanently irretrievable.
          </div>

          <h2>1. In-App Self-Service Deletion (Immediate)</h2>
          <p>
            You can delete your entire account, all message history, cryptographic keys, and cached relay bundles immediately from within the application:
          </p>
          <ol>
            <li>Open the <strong>OffMesh</strong> app on your Android device.</li>
            <li>Tap the <strong>Settings</strong> icon in the bottom navigation bar.</li>
            <li>Select <strong>Storage &amp; Data</strong>.</li>
            <li>Scroll to the bottom of the screen and tap the red action button: <strong>&quot;Wipe All Keys &amp; Local Data&quot;</strong>.</li>
            <li>Review the confirmation dialog warning that this action is irreversible.</li>
            <li>Confirm by tapping <strong>&quot;Confirm Permanent Deletion&quot;</strong>.</li>
          </ol>

          <h3>What happens when you confirm in-app wipe?</h3>
          <ul>
            <li><strong>Hardware Keystore Purge:</strong> Your Ed25519 signing key and Curve25519 private encryption key are deleted from Android KeyStore / TEE hardware.</li>
            <li><strong>Local SQLite Database Zeroized:</strong> All stored conversations, incoming and outgoing message bubbles, and contact fingerprints are erased from your phone&apos;s flash storage.</li>
            <li><strong>Mesh Cache Flushed:</strong> All temporary opportunistic relay packets stored on your phone for multi-hop mesh forwarding are instantly deleted.</li>
            <li>The app returns to its initial uninitialized onboarding screen.</li>
          </ul>

          <h2>2. Server-Held Transient Packets Deletion</h2>
          <p>
            Because OffMesh is a delay-tolerant network, if you sent a message to an offline recipient, an encrypted copy may temporarily reside in our Cloud Gateway buffer waiting for the recipient to come online:
          </p>
          <ul>
            <li><strong>Automatic TTL Expiration:</strong> All transient server-buffered packets have a strict Time-To-Live (TTL, default 7 days). When the TTL expires, packets are automatically and irreversibly purged from our Redis memory cache and PostgreSQL database.</li>
            <li><strong>Immediate Receipt Purge:</strong> The moment a recipient device receives and acknowledges the bundle with a signed anti-packet receipt, the server copy is deleted immediately.</li>
          </ul>

          <h2>3. Requesting Manual Server Deletion via Support</h2>
          <p>
            If you wish to request manual verification or premature deletion of any pending encrypted packets associated with your public key fingerprint from our gateway buffer:
          </p>
          <ol>
            <li>Send an email to <a href="mailto:simplicion.com@gmail.com">simplicion.com@gmail.com</a> from your preferred email address.</li>
            <li>Include the subject line: <code>OffMesh Data Deletion Request - [Your Public Device Fingerprint]</code>.</li>
            <li>Provide your 32-byte hexadecimal public device fingerprint (found in <code>Settings &gt; Account &gt; Device Identity</code>).</li>
            <li>Our engineering team will execute a complete purge of all pending packets matching that fingerprint from all gateway caches within <strong>24 to 48 hours</strong> and send you written confirmation.</li>
          </ol>

          <h2>4. Data Retention Schedule Table</h2>
          <table className={styles.complianceTable}>
            <thead>
              <tr>
                <th>Data Type</th>
                <th>Storage Location</th>
                <th>Retention Period</th>
                <th>Deletion Method</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><strong>Private Keys (Ed25519 / Curve25519)</strong></td>
                <td>Device TEE / Hardware Keystore</td>
                <td>Until user wipes or uninstalls</td>
                <td>Instant local wipe in Settings</td>
              </tr>
              <tr>
                <td><strong>Conversation History &amp; Messages</strong></td>
                <td>Device Encrypted SQLite Database</td>
                <td>Until deleted by user</td>
                <td>Instant local wipe in Settings</td>
              </tr>
              <tr>
                <td><strong>Transient Relay Bundles</strong></td>
                <td>Device Temporary Cache</td>
                <td>Max 7 days or until forwarded</td>
                <td>Automatic pruning / Instant wipe</td>
              </tr>
              <tr>
                <td><strong>Gateway Buffered Packets</strong></td>
                <td>Cloud Gateway (Server Buffer)</td>
                <td>Max 7 days (TTL)</td>
                <td>Automatic cron worker / Manual purge</td>
              </tr>
              <tr>
                <td><strong>Personal Profile Data</strong></td>
                <td>None (Never collected)</td>
                <td>0 seconds</td>
                <td>Not applicable (Never stored)</td>
              </tr>
            </tbody>
          </table>

          <h2>5. Uninstalling the Application</h2>
          <p>
            Uninstalling the OffMesh application from your Android device immediately deletes the application sandbox, removing all local SQLite databases and cached bundles. To ensure your hardware keystore entries are cleanly scrubbed prior to uninstalling, we recommend executing the in-app wipe described in Section 1.
          </p>

          <h2>6. Contact Developer &amp; Data Protection Officer</h2>
          <div className={styles.calloutBox}>
            <strong>Simplicion Private Limited</strong><br />
            Attn: Data Privacy &amp; Deletion Compliance<br />
            Address: Dpt 808b F-79&amp;80 Dlf Prime Tower, Okhla Industrial Area Phase-i, New Delhi - 110020, India<br />
            Email: <a href="mailto:simplicion.com@gmail.com">simplicion.com@gmail.com</a><br />
            Website: <a href="https://simplicion.com/" target="_blank" rel="noopener noreferrer">https://simplicion.com/</a>
          </div>

          <div className={styles.complianceFooterBox}>
            <Link to="/" className="button button--secondary button--sm">
              ← Return to OffMesh Overview
            </Link>
            <div style={{ display: 'flex', gap: '8px' }}>
              <Link to="/privacy" className="button button--secondary button--sm">
                Privacy Policy
              </Link>
              <Link to="/terms" className="button button--secondary button--sm">
                Terms of Service
              </Link>
              <Link to="/data-safety" className="button button--secondary button--sm">
                Data Safety
              </Link>
            </div>
          </div>
        </main>
      </div>
    </Layout>
  );
}
