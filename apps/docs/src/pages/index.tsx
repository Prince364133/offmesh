import React from 'react';
import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';
import styles from './index.module.css';

export default function Home(): ReactNode {
  return (
    <Layout
      title="OffMesh — Off-Grid, Delay-Tolerant Encrypted Mesh Messenger"
      description="Decentralized, delay-tolerant offline smartphone-to-smartphone messaging engine and opportunistic store-and-forward mesh platform by Simplicion Private Limited.">
      <div className={styles.landingPage}>
        {/* HERO SECTION */}
        <header className={styles.heroSection}>
          <div className={styles.heroBadge}>
            <span className={styles.heroBadgeDot}></span>
            <span>Production v1.0.1+2 (Version Code 2) • Signed & Ready for Google Play</span>
          </div>

          <div className={styles.heroLogoContainer}>
            <svg
              className={styles.heroLogo}
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 512 512"
              fill="none"
              aria-label="OffMesh Diamond Mark">
              <path d="M 247.5,74.3 L 248.0,104.6 L 239.5,242.2 L 234.7,244.4 L 152.3,241.7 L 82.2,243.9 L 247.0,74.9 Z" fill="currentColor" />
              <path d="M 267.2,77.1 L 340.0,149.7 L 277.8,221.3 L 262.9,234.5 L 267.2,77.6 Z" fill="currentColor" />
              <path d="M 352.8,162.4 L 439.9,249.4 L 439.9,252.1 L 339.5,252.1 L 339.5,245.0 L 360.7,194.9 L 358.6,188.8 L 349.6,186.6 L 345.3,180.0 L 352.2,162.9 Z" fill="currentColor" />
              <path d="M 341.1,179.5 L 344.2,180.6 L 342.1,186.6 L 261.3,385.4 L 259.2,385.9 L 258.7,377.7 L 262.9,268.7 L 340.5,180.0 Z" fill="currentColor" />
              <path d="M 197.5,261.5 L 234.2,263.2 L 235.3,266.5 L 160.3,350.2 L 74.2,263.7 L 197.0,262.1 Z" fill="currentColor" />
              <path d="M 423.5,272.5 L 427.2,275.3 L 262.4,439.9 L 327.2,276.4 L 422.9,273.1 Z" fill="currentColor" />
              <path d="M 240.1,293.4 L 242.2,298.9 L 236.3,426.7 L 174.7,364.5 L 239.5,294.0 Z" fill="currentColor" />
            </svg>
          </div>

          <Heading as="h1" className={styles.heroTitle}>
            Off-Grid, Delay-Tolerant<br />Encrypted Mesh Messenger
          </Heading>

          <p className={styles.heroSubtitle}>
            Stay connected, even when the internet isn&apos;t available. Direct peer-to-peer radio mesh over Bluetooth Low Energy &amp; Wi-Fi Direct, hardware-backed end-to-end encryption, and mathematically verified honest delivery confirmation.
          </p>

          <div className={styles.heroActions}>
            <a
              href="/downloads/offmesh-v1.0.1.apk"
              className={styles.primaryCta}
              download="offmesh-v1.0.1.apk">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM17 13l-5 5-5-5h3V9h4v4h3z" />
              </svg>
              <span>Download Release APK (50.5 MB)</span>
            </a>

            <a
              href="/downloads/offmesh-v1.0.1.aab"
              className={styles.secondaryCta}
              download="offmesh-v1.0.1.aab">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M3 3h18v18H3V3zm16 16V5H5v14h14zM11 7h2v6h-2V7zm0 8h2v2h-2v-2z" />
              </svg>
              <span>Download Play Store AAB (49.3 MB)</span>
            </a>

            <Link to="/docs/intro" className={styles.secondaryCta}>
              <span>Explore Documentation →</span>
            </Link>
          </div>

          {/* Quick Metrics */}
          <div className={styles.metricsGrid}>
            <div className={styles.metricCard}>
              <div className={styles.metricVal}>0 Towers</div>
              <div className={styles.metricLabel}>Works 100% off-grid with zero cellular or Wi-Fi towers</div>
            </div>
            <div className={styles.metricCard}>
              <div className={styles.metricVal}>100% TEE</div>
              <div className={styles.metricLabel}>Keys protected by Android KeyStore hardware security</div>
            </div>
            <div className={styles.metricCard}>
              <div className={styles.metricVal}>15 µs</div>
              <div className={styles.metricLabel}>Ultra-fast Merkle root exchange during brief physical passing</div>
            </div>
            <div className={styles.metricCard}>
              <div className={styles.metricVal}>4 Stages</div>
              <div className={styles.metricLabel}>Honest delivery confirmation backed by digital signatures</div>
            </div>
          </div>
        </header>

        {/* SECTION 1: HONEST DELIVERY STATUSES */}
        <section id="delivery-states" className={styles.sectionContainer}>
          <div className={styles.sectionHeader}>
            <span className={styles.sectionBadge}>UI/UX Core Principle</span>
            <Heading as="h2" className={styles.sectionTitle}>
              Honest Delivery Feedback
            </Heading>
            <p className={styles.sectionSubtitle}>
              In life-critical emergency and off-grid scenarios, false confirmation can cost lives. Conventional apps show &quot;Sent&quot; when a message leaves the phone. OffMesh strictly describes what the network actually knows.
            </p>
          </div>

          <div className={styles.statusGrid}>
            <div className={styles.statusCard}>
              <div className={styles.statusHeader}>
                <span className={`${styles.statusPill} ${styles.statusPillQueued}`}>
                  ⏳ QUEUED
                </span>
                <span className={styles.statusStep}>Stage 1</span>
              </div>
              <div className={styles.statusCardTitle}>Local Storage</div>
              <div className={styles.statusCardMicrocopy}>
                &quot;Waiting for a connection&quot;
              </div>
              <p className={styles.statusCardDesc}>
                The encrypted packet is signed and sealed on local flash storage. No peer, relay carrier, or gateway has received it yet.
              </p>
            </div>

            <div className={styles.statusCard}>
              <div className={styles.statusHeader}>
                <span className={`${styles.statusPill} ${styles.statusPillForwarded}`}>
                  ✉ FORWARDED
                </span>
                <span className={styles.statusStep}>Stage 2</span>
              </div>
              <div className={styles.statusCardTitle}>Physical Transit</div>
              <div className={styles.statusCardMicrocopy}>
                &quot;Being carried by nearby devices&quot;
              </div>
              <p className={styles.statusCardDesc}>
                Replicated to permitted intermediate smartphones (hop count up to 5). The sender knows the packet is in physical motion.
              </p>
            </div>

            <div className={styles.statusCard}>
              <div className={styles.statusHeader}>
                <span className={`${styles.statusPill} ${styles.statusPillUploaded}`}>
                  ☁ UPLOADED
                </span>
                <span className={styles.statusStep}>Stage 3</span>
              </div>
              <div className={styles.statusCardTitle}>Gateway Buffer</div>
              <div className={styles.statusCardMicrocopy}>
                &quot;Stored on server — waiting for recipient&quot;
              </div>
              <p className={styles.statusCardDesc}>
                A relay with internet access uploaded the bundle to the Cloud Gateway buffer. The recipient is still offline.
              </p>
            </div>

            <div className={styles.statusCard}>
              <div className={styles.statusHeader}>
                <span className={`${styles.statusPill} ${styles.statusPillDelivered}`}>
                  ✔ DELIVERED
                </span>
                <span className={styles.statusStep}>Stage 4</span>
              </div>
              <div className={styles.statusCardTitle}>Cryptographic Receipt</div>
              <div className={styles.statusCardMicrocopy}>
                &quot;Delivered&quot;
              </div>
              <p className={styles.statusCardDesc}>
                An Anti-Packet receipt containing the recipient&apos;s Ed25519 digital signature has arrived. Mathematical proof of non-repudiation.
              </p>
            </div>
          </div>
        </section>

        {/* SECTION 2: CORE ARCHITECTURE FEATURES */}
        <section id="features" className={styles.sectionContainer} style={{ paddingTop: '1rem' }}>
          <div className={styles.sectionHeader}>
            <span className={styles.sectionBadge}>Technical Capabilities</span>
            <Heading as="h2" className={styles.sectionTitle}>
              Engineered for Adversarial &amp; Disconnected Realities
            </Heading>
            <p className={styles.sectionSubtitle}>
              Built on a foundation of delay-tolerant networking, modern elliptic-curve cryptography, and zero-compromise privacy.
            </p>
          </div>

          <div className={styles.featuresGrid}>
            <div className={styles.featureCard}>
              <div className={styles.featureIconBox}>📡</div>
              <div className={styles.featureTitle}>Zero-Internet Radio Mesh</div>
              <p className={styles.featureDesc}>
                Communicates directly over Bluetooth Low Energy (BLE) and Wi-Fi Direct. Devices discover each other peer-to-peer and establish opportunistic links without central coordination.
              </p>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.featureIconBox}>🔒</div>
              <div className={styles.featureTitle}>Hardware-TEE E2E Encryption</div>
              <p className={styles.featureDesc}>
                Curve25519 ECDH key exchange combined with ChaCha20-Poly1305 AEAD authenticated encryption. Private keys remain protected inside Android KeyStore hardware. Relays carry opaque sealed payloads.
              </p>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.featureIconBox}>📦</div>
              <div className={styles.featureTitle}>Delay-Tolerant Store &amp; Forward</div>
              <p className={styles.featureDesc}>
                Engineered for natural disasters, hiking trails, rural villages, and cellular blackout zones. Packets are cached on intermediate devices and forwarded when encountering new peers.
              </p>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.featureIconBox}>🌲</div>
              <div className={styles.featureTitle}>Microsecond Merkle Sync</div>
              <p className={styles.featureDesc}>
                Time-bucketed hierarchical Merkle trees reconcile message state in under 15 microseconds. Passing pedestrians exchange missing bundles effortlessly in brief radio connection windows.
              </p>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.featureIconBox}>🛡</div>
              <div className={styles.featureTitle}>Privacy by Default</div>
              <p className={styles.featureDesc}>
                No phone number, no email address, no advertising IDs, and no third-party tracking SDKs. Identities are cryptographic Ed25519 public keys generated locally on your physical device.
              </p>
            </div>

            <div className={styles.featureCard}>
              <div className={styles.featureIconBox}>⚡</div>
              <div className={styles.featureTitle}>Battery-Aware Radio Scheduler</div>
              <p className={styles.featureDesc}>
                Adaptive scanning intervals respect Android background execution limits and preserve device battery life. Relaying respects user preferences, storage limits, and Wi-Fi-only policies.
              </p>
            </div>
          </div>
        </section>

        {/* SECTION 3: PRODUCTION DOWNLOAD & PLAY STORE RELEASE */}
        <section id="download" className={styles.sectionContainer} style={{ paddingTop: '1rem' }}>
          <div className={styles.downloadBox}>
            <div>
              <span className={styles.sectionBadge}>Release Artifacts</span>
              <Heading as="h2" className={styles.downloadInfoTitle}>
                OffMesh for Android
              </Heading>
              <p className={styles.downloadInfoSub}>
                Production release v1.0.1+2 is compiled and cryptographically signed with the official Simplicion Private Limited upload keystore.
              </p>

              <table className={styles.buildMetaTable}>
                <tbody>
                  <tr>
                    <td>Package Identifier</td>
                    <td>net.offmesh.app</td>
                  </tr>
                  <tr>
                    <td>Version &amp; Build</td>
                    <td>1.0.1+2 (Version Code 2)</td>
                  </tr>
                  <tr>
                    <td>Target Platforms</td>
                    <td>Android 8.0+ (API 26+)</td>
                  </tr>
                  <tr>
                    <td>Signature Keystore</td>
                    <td>Simplicion Private Limited Upload Keystore</td>
                  </tr>
                  <tr>
                    <td>SHA-256 Fingerprint</td>
                    <td style={{ fontSize: '0.75rem', wordBreak: 'break-all' }}>
                      68:FB:61:0E:59:16:90:28:2D:42:95:1B:D8:10:80:81:54:22:EF:95:D5:CF:A0:68:BE:33:AD:09:FC:F0:EA:83
                    </td>
                  </tr>
                </tbody>
              </table>

              <div className={styles.downloadButtons}>
                <a
                  href="/downloads/offmesh-v1.0.1.apk"
                  className={styles.primaryCta}
                  download="offmesh-v1.0.1.apk">
                  Download APK (v1.0.1)
                </a>
                <a
                  href="/downloads/offmesh-v1.0.1.aab"
                  className={styles.secondaryCta}
                  download="offmesh-v1.0.1.aab">
                  Download AAB Bundle
                </a>
              </div>
            </div>

            <div className={styles.downloadActionsSide}>
              <div className={styles.storeBadgeBox}>
                <div>Google Play Status</div>
                <div style={{ fontSize: '0.8125rem', color: 'var(--offmesh-status-success)', marginTop: '4px' }}>
                  ● Organization Account Ready
                </div>
                <div style={{ fontSize: '0.75rem', color: 'var(--offmesh-text-secondary)', marginTop: '4px' }}>
                  Developer: Simplicion Private Limited
                </div>
              </div>

              <div style={{ fontSize: '0.8125rem', color: 'var(--offmesh-text-secondary)', lineHeight: 1.5 }}>
                Direct APK installation requires enabling &quot;Install from unknown sources&quot; in Android security settings for manual sideloading.
              </div>

              <Link to="/deletion" style={{ fontSize: '0.8125rem', color: 'var(--offmesh-text-secondary)', textDecoration: 'underline' }}>
                Account &amp; Data Deletion Policy →
              </Link>
            </div>
          </div>
        </section>

        {/* SECTION 4: PLAY STORE COMPLIANCE QUICK REFERENCE */}
        <section className={styles.complianceBanner}>
          <div className={styles.complianceInner}>
            <div className={styles.sectionHeader} style={{ marginBottom: '1.5rem' }}>
              <span className={styles.sectionBadge}>Transparency &amp; Legal</span>
              <Heading as="h2" className={styles.sectionTitle} style={{ fontSize: '1.75rem' }}>
                Google Play Store Compliance Center
              </Heading>
              <p className={styles.sectionSubtitle} style={{ fontSize: '0.9375rem' }}>
                Complete legal, cryptographic, privacy, and data-safety documentation for Google Play Console submission and user transparency.
              </p>
            </div>

            <div className={styles.complianceCardsGrid}>
              <Link to="/privacy" className={styles.complianceCard}>
                <div>
                  <div className={styles.complianceCardTitle}>Privacy Policy</div>
                  <p className={styles.complianceCardDesc}>
                    Zero PII collection, zero third-party trackers, and strict disclosure of radio permissions.
                  </p>
                </div>
                <span className={styles.complianceCardLink}>View Policy →</span>
              </Link>

              <Link to="/terms" className={styles.complianceCard}>
                <div>
                  <div className={styles.complianceCardTitle}>Terms of Service</div>
                  <p className={styles.complianceCardDesc}>
                    Decentralized relay terms, honest delivery disclaimers, acceptable use, and liability limits.
                  </p>
                </div>
                <span className={styles.complianceCardLink}>Read Terms →</span>
              </Link>

              <Link to="/data-safety" className={styles.complianceCard}>
                <div>
                  <div className={styles.complianceCardTitle}>Data Safety Disclosure</div>
                  <p className={styles.complianceCardDesc}>
                    Exact questionnaire responses for Google Play Console Data Safety declarations.
                  </p>
                </div>
                <span className={styles.complianceCardLink}>Review Safety Spec →</span>
              </Link>

              <Link to="/deletion" className={styles.complianceCard}>
                <div>
                  <div className={styles.complianceCardTitle}>Account &amp; Data Deletion</div>
                  <p className={styles.complianceCardDesc}>
                    Mandatory Google Play compliance instructions for wiping cryptographic keys &amp; cached bundles.
                  </p>
                </div>
                <span className={styles.complianceCardLink}>Deletion Guide →</span>
              </Link>

              <Link to="/contact" className={styles.complianceCard}>
                <div>
                  <div className={styles.complianceCardTitle}>Developer Details</div>
                  <p className={styles.complianceCardDesc}>
                    Simplicion Private Limited contact details, registered address in New Delhi, and support desk.
                  </p>
                </div>
                <span className={styles.complianceCardLink}>Contact Entity →</span>
              </Link>
            </div>
          </div>
        </section>
      </div>
    </Layout>
  );
}
