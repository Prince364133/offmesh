import React from 'react';
import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';
import styles from './compliance.module.css';

export default function DataSafety(): ReactNode {
  return (
    <Layout
      title="Google Play Data Safety Disclosure — OffMesh"
      description="Official Google Play Console Data Safety questionnaire mapping and cryptographic security disclosure for OffMesh by Simplicion Private Limited.">
      <div className={styles.complianceContainer}>
        <header className={styles.complianceHeader}>
          <span className={styles.complianceBadge}>Google Play Compliance</span>
          <Heading as="h1" className={styles.complianceTitle}>
            Data Safety &amp; Security Disclosure
          </Heading>
          <p style={{ color: 'var(--offmesh-text-secondary)', margin: 0 }}>
            This document provides the definitive data collection, sharing, and encryption disclosures for the OffMesh application (<code>net.offmesh.app</code>), specifically formatted to correspond with the Google Play Console Data Safety questionnaire.
          </p>

          <div className={styles.complianceMetaGrid}>
            <div>
              <div className={styles.complianceMetaLabel}>Developer / Publisher</div>
              <div className={styles.complianceMetaValue}>Simplicion Private Limited</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>Package Identifier</div>
              <div className={styles.complianceMetaValue}>net.offmesh.app</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>App Category</div>
              <div className={styles.complianceMetaValue}>Communication / Utilities</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>Data Collection Summary</div>
              <div className={styles.complianceMetaValue} style={{ color: 'var(--offmesh-status-success)' }}>
                Zero User Data Collected
              </div>
            </div>
          </div>
        </header>

        <main className={styles.complianceContent}>
          <div className={styles.calloutBox}>
            <strong>Play Console Summary for Reviewers:</strong> OffMesh does not collect, harvest, monetize, or share any personal user data. Messages are strictly End-to-End Encrypted (E2EE). Ephemeral packets buffered by the server or intermediate relays are cryptographically opaque and automatically purged upon delivery or TTL expiry.
          </div>

          <h2>1. Data Safety Questionnaire Responses</h2>
          <p>
            When completing or reviewing the Google Play Console Data Safety section for OffMesh, the answers are defined as follows:
          </p>

          <table className={styles.complianceTable}>
            <thead>
              <tr>
                <th style={{ width: '45%' }}>Google Play Question</th>
                <th>OffMesh Formal Declaration</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><strong>Does your app collect or share any of the required user data types?</strong></td>
                <td>
                  <strong>No.</strong> OffMesh does not collect or share any user personal information or device telemetry.
                </td>
              </tr>
              <tr>
                <td><strong>Is all of the user data collected by your app encrypted in transit?</strong></td>
                <td>
                  <strong>Yes.</strong> All communications (peer-to-peer over BLE/Wi-Fi Direct and client-to-gateway over TLS 1.3) are end-to-end encrypted using Curve25519 and ChaCha20-Poly1305.
                </td>
              </tr>
              <tr>
                <td><strong>Do you provide a way for users to request that their data be deleted?</strong></td>
                <td>
                  <strong>Yes.</strong> Users can instantly wipe all cryptographic identity keys and local database records within the app (<code>Settings &gt; Storage &amp; Data &gt; Wipe All Keys &amp; Data</code>). Server packets expire automatically.
                </td>
              </tr>
              <tr>
                <td><strong>Does your app commit to following the Families Policy?</strong></td>
                <td>
                  OffMesh is rated for general audiences (not targeted primarily at children under 13).
                </td>
              </tr>
              <tr>
                <td><strong>Has your app been independently validated against a global security standard?</strong></td>
                <td>
                  OffMesh architecture strictly adheres to OWASP Mobile Application Security Verification Standard (MASVS-CRYPTO and MASVS-STORAGE Level 2).
                </td>
              </tr>
            </tbody>
          </table>

          <h2>2. Detailed Data Category Inventory</h2>
          <p>
            The table below provides a granular analysis of every standard Google Play data type and how OffMesh handles it:
          </p>

          <table className={styles.complianceTable}>
            <thead>
              <tr>
                <th>Data Category</th>
                <th>Collected?</th>
                <th>Shared?</th>
                <th>Handling &amp; Architecture Details</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td><strong>Location</strong> (Approximate / Precise)</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td>
                  Android requires <code>ACCESS_FINE_LOCATION</code> solely to scan for local Bluetooth Low Energy radio signals. OffMesh <strong>never</strong> queries, reads, records, or transmits GPS coordinates to any server.
                </td>
              </tr>
              <tr>
                <td><strong>Personal Info</strong> (Name, Email, Phone, User ID, Address)</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td>
                  OffMesh does not ask for or store phone numbers, email addresses, real names, or national identification.
                </td>
              </tr>
              <tr>
                <td><strong>Financial Info</strong> (Credit card, Bank accounts)</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td>OffMesh is completely free with zero in-app purchases or payment processing.</td>
              </tr>
              <tr>
                <td><strong>Messages</strong> (Emails, SMS, In-app chat messages)</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td>
                  Messages are end-to-end encrypted locally before dispatch. Neither intermediate relay phones nor our Cloud Gateway possess the decryption keys. Relays see only opaque ciphertext.
                </td>
              </tr>
              <tr>
                <td><strong>Photos &amp; Videos</strong></td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td>Attachments are encrypted locally with symmetric session keys and sent directly to the recipient. We do not operate cloud photo storage.</td>
              </tr>
              <tr>
                <td><strong>Audio Files</strong></td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td>Voice notes (if sent) are treated as encrypted binary blobs; not collected or analyzed.</td>
              </tr>
              <tr>
                <td><strong>Contacts &amp; Address Book</strong></td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td>OffMesh does not access device contacts. Friends are exchanged directly via physical QR code scanning or direct radio proximity.</td>
              </tr>
              <tr>
                <td><strong>App Activity &amp; Analytics</strong></td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td>Zero third-party analytics libraries. No user action tracking, no telemetry logging.</td>
              </tr>
              <tr>
                <td><strong>Crash Logs &amp; Diagnostics</strong></td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td>Diagnostics remain strictly on the local device screen in the diagnostics view. No automated crash reporting SDKs are installed.</td>
              </tr>
              <tr>
                <td><strong>Device or Other Identifiers</strong> (IMEI, MAC, Advertising ID)</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td style={{ color: 'var(--offmesh-status-success)', fontWeight: 600 }}>No</td>
                <td>No hardware serials, IMEI, or Google Advertising IDs are queried or transmitted. OffMesh uses self-generated Ed25519 public keys.</td>
              </tr>
            </tbody>
          </table>

          <h2>3. Cryptographic Security Standards</h2>
          <p>
            OffMesh implements industry-standard cryptography:
          </p>
          <ul>
            <li><strong>Key Generation:</strong> Curve25519 (X25519) keypairs generated via operating system cryptographically secure pseudorandom number generators (CSPRNG).</li>
            <li><strong>Hardware Isolation:</strong> Android KeyStore backing using Trusted Execution Environment (TEE) or StrongBox keymaster where supported by hardware.</li>
            <li><strong>Symmetric Encryption:</strong> ChaCha20-Poly1305 with 256-bit keys and 96-bit unique nonces per message.</li>
            <li><strong>Integrity &amp; Anti-Repudiation:</strong> Ed25519 digital signatures on all delivery receipts and bundle headers.</li>
          </ul>

          <h2>4. Data Deletion Verification</h2>
          <p>
            Google Play requires a dedicated, publicly accessible URL explaining how users can request deletion of their data. That URL is formally published at:
          </p>
          <div className={styles.calloutBox}>
            <strong>OffMesh Data Deletion Guide URL:</strong><br />
            <Link to="/deletion">https://offmesh.simplicion.com/deletion</Link>
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
