import React from 'react';
import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';
import styles from './compliance.module.css';

export default function TermsOfService(): ReactNode {
  return (
    <Layout
      title="Terms of Service — OffMesh"
      description="Official Terms of Service for OffMesh by Simplicion Private Limited. Explaining decentralized relay terms, honest delivery disclaimers, and user responsibilities.">
      <div className={styles.complianceContainer}>
        <header className={styles.complianceHeader}>
          <span className={styles.complianceBadge}>Terms &amp; Conditions</span>
          <Heading as="h1" className={styles.complianceTitle}>
            Terms of Service
          </Heading>
          <p style={{ color: 'var(--offmesh-text-secondary)', margin: 0 }}>
            These Terms of Service (&quot;Terms&quot;) constitute a legally binding agreement between you and Simplicion Private Limited (&quot;Company&quot;, &quot;we&quot;, &quot;us&quot;, or &quot;our&quot;) governing your use of the OffMesh mobile software application (<code>net.offmesh.app</code>) and related communication services.
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
              <div className={styles.complianceMetaLabel}>Jurisdiction</div>
              <div className={styles.complianceMetaValue}>New Delhi, India</div>
            </div>
          </div>
        </header>

        <main className={styles.complianceContent}>
          <div className={styles.calloutBox}>
            <strong>Important Notice:</strong> By installing, accessing, or using the OffMesh application, you agree to be bound by these Terms. If you do not agree, do not install or use OffMesh. OffMesh is an offline-capable, decentralized peer-to-peer messaging application. Please read our Delivery Disclaimers carefully.
          </div>

          <h2>1. Description of Service</h2>
          <p>
            OffMesh provides peer-to-peer, delay-tolerant, end-to-end encrypted messaging designed to function when internet infrastructure is degraded, partitioned, or completely absent. The software enables:
          </p>
          <ul>
            <li>Direct local radio discovery and message exchange via Bluetooth Low Energy (BLE) and Wi-Fi Direct.</li>
            <li>Opportunistic, delay-tolerant store-and-forward relaying where intermediate devices carry sealed, encrypted packets between disconnected nodes.</li>
            <li>Optional server-assisted gateway forwarding when devices encounter internet connectivity.</li>
          </ul>

          <h2>2. Honest Delivery Disclaimers &amp; Limitations</h2>
          <h3>2.1 Physical Network Constraints</h3>
          <p>
            OffMesh relies on the physical movement and proximity of participating smartphones. Because transmission depends on real-world radio propagation and physical encounters:
          </p>
          <ul>
            <li><strong>No Guaranteed Delivery Times:</strong> We do not and cannot guarantee specific delivery times. Messages may remain in local queues or intermediate relays until an appropriate physical or internet route becomes available.</li>
            <li><strong>Partitioned Networks:</strong> If a recipient remains physically isolated and no relay or gateway route exists, messages may expire before delivery. OffMesh accurately reflects this state as <code>EXPIRED</code> or <code>QUEUED</code> and will never falsely display a &quot;Delivered&quot; confirmation.</li>
          </ul>

          <h3>2.2 Not a Replacement for Emergency Services</h3>
          <p>
            <strong>OffMesh is NOT a replacement for primary emergency phone services (such as 911, 112, 999, or local emergency dispatchers).</strong> You should not rely on OffMesh as your sole communication tool for life-threatening situations where immediate, guaranteed dispatch is required.
          </p>

          <h2>3. User Responsibilities &amp; Cryptographic Keys</h2>
          <p>
            OffMesh operates under a zero-knowledge, decentralized architecture:
          </p>
          <ul>
            <li><strong>Device Security:</strong> Your cryptographic identity keys (Ed25519) and message decryption keys (Curve25519) reside exclusively on your physical device. You are solely responsible for protecting your device against unauthorized physical access.</li>
            <li><strong>No Key Recovery:</strong> Because we do not possess your private keys, <strong>we cannot recover lost keys, lost PINs, or deleted messages</strong>. If you uninstall the app or wipe device storage without backup, your identity and history cannot be restored.</li>
          </ul>

          <h2>4. Acceptable Use Policy</h2>
          <p>
            You agree to use OffMesh only for lawful purposes. You agree not to:
          </p>
          <ul>
            <li>Transmit malicious code, viruses, worms, or automated Denial of Service (DoS) payloads intended to exhaust peer battery, memory, or storage.</li>
            <li>Attempt to interfere with or disrupt the integrity of the opportunistic relay network.</li>
            <li>Use the software for harassment, unlawful surveillance, or in violation of applicable local, national, or international laws.</li>
          </ul>

          <h2>5. Relay Participation Controls</h2>
          <p>
            By default, OffMesh enables opportunistic store-and-forward relaying to assist community communication. You retain full control over your relay participation at all times. Through <strong>Settings &gt; Mesh &amp; Connectivity</strong>, you may:
          </p>
          <ul>
            <li>Disable relay participation entirely.</li>
            <li>Limit relaying to times when your device is connected to Wi-Fi or charging.</li>
            <li>Set strict storage limits on transient cached bundles.</li>
          </ul>

          <h2>6. Intellectual Property</h2>
          <p>
            The OffMesh software, brand trademarks, logos, visual designs, and associated code are the intellectual property of Simplicion Private Limited and its licensors. Open-source components are subject to their respective open-source licenses.
          </p>

          <h2>7. Disclaimer of Warranties</h2>
          <p>
            THE SOFTWARE IS PROVIDED &quot;AS IS&quot; AND &quot;AS AVAILABLE&quot;, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE OPERATION OF THE SOFTWARE WILL BE UNINTERRUPTED, ERROR-FREE, OR FULLY DELIVERED UNDER ALL PHYSICAL OR WIRELESS CONDITIONS.
          </p>

          <h2>8. Limitation of Liability</h2>
          <p>
            TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, IN NO EVENT SHALL SIMPLICION PRIVATE LIMITED, ITS DIRECTORS, EMPLOYEES, OR PARTNERS BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING WITHOUT LIMITATION, LOSS OF DATA, LOSS OF PROFITS, OR PERSONAL HARM RESULTING FROM YOUR ACCESS TO OR INABILITY TO USE THE SERVICE.
          </p>

          <h2>9. Governing Law and Dispute Resolution</h2>
          <p>
            These Terms shall be governed by and construed in accordance with the laws of India. Any legal dispute, controversy, or claim arising out of or relating to these Terms or the OffMesh application shall be subject to the exclusive jurisdiction of the competent courts in New Delhi, India.
          </p>

          <h2>10. Changes to Terms</h2>
          <p>
            We may update these Terms periodically. We will indicate the effective date of any modifications at the top of this document. Continued use of OffMesh after such modifications constitutes your acceptance of the revised Terms.
          </p>

          <h2>11. Contact Information</h2>
          <div className={styles.calloutBox}>
            <strong>Simplicion Private Limited</strong><br />
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
