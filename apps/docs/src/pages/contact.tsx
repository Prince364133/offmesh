import React from 'react';
import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';
import styles from './compliance.module.css';

export default function DeveloperContact(): ReactNode {
  return (
    <Layout
      title="Developer & Corporate Contact — OffMesh"
      description="Official contact and corporate details for Simplicion Private Limited, the publisher and developer of OffMesh on Google Play Store.">
      <div className={styles.complianceContainer}>
        <header className={styles.complianceHeader}>
          <span className={styles.complianceBadge}>Developer Transparency</span>
          <Heading as="h1" className={styles.complianceTitle}>
            Developer Details &amp; Corporate Contact
          </Heading>
          <p style={{ color: 'var(--offmesh-text-secondary)', margin: 0 }}>
            OffMesh is developed, published, and maintained by Simplicion Private Limited, an incorporated technology company based in New Delhi, India.
          </p>

          <div className={styles.complianceMetaGrid}>
            <div>
              <div className={styles.complianceMetaLabel}>Legal Entity Name</div>
              <div className={styles.complianceMetaValue}>Simplicion Private Limited</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>Google Play Account ID</div>
              <div className={styles.complianceMetaValue}>6740546592199527613</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>Developer Status</div>
              <div className={styles.complianceMetaValue}>Verified Organization</div>
            </div>
            <div>
              <div className={styles.complianceMetaLabel}>Primary Email</div>
              <div className={styles.complianceMetaValue}>simplicion.com@gmail.com</div>
            </div>
          </div>
        </header>

        <main className={styles.complianceContent}>
          <h2>1. Official Corporate Headquarters</h2>
          <div className={styles.calloutBox}>
            <strong>Simplicion Private Limited</strong><br />
            <strong>Registered Office Address:</strong><br />
            Dpt 808b F-79&amp;80 Dlf Prime Tower,<br />
            Okhla Industrial Area Phase-i,<br />
            New Delhi - 110020, India<br /><br />
            <strong>Primary Contact Email:</strong> <a href="mailto:simplicion.com@gmail.com">simplicion.com@gmail.com</a><br />
            <strong>Official Corporate Website:</strong> <a href="https://simplicion.com/" target="_blank" rel="noopener noreferrer">https://simplicion.com/</a>
          </div>

          <h2>2. Support Desk &amp; Inquiries</h2>
          <p>
            For user support, feedback, bug reports, and data protection inquiries:
          </p>
          <ul>
            <li><strong>Technical Support:</strong> <a href="mailto:simplicion.com@gmail.com">simplicion.com@gmail.com</a></li>
            <li><strong>Response Window:</strong> We aim to acknowledge and address all user inquiries within <strong>24 to 48 business hours</strong>.</li>
            <li><strong>Bug Reports &amp; Open Source Community:</strong> <a href="https://github.com/Prince364133/offline-messaging/issues" target="_blank" rel="noopener noreferrer">GitHub Issues Portal</a></li>
          </ul>

          <h2>3. Coordinated Vulnerability Disclosure &amp; Security Reporting</h2>
          <p>
            OffMesh takes cryptographic security and relay integrity with extreme seriousness. If you discover a vulnerability, cryptographic weakness, or security defect in OffMesh:
          </p>
          <ul>
            <li>Please email our engineering security team directly at <a href="mailto:simplicion.com@gmail.com">simplicion.com@gmail.com</a> with the subject <code>[SECURITY DISCLOSURE] OffMesh Vulnerability</code>.</li>
            <li>Include a detailed proof of concept, affected version, and reproduction steps.</li>
            <li>We adhere to responsible disclosure principles and will respond within 24 hours to validate and begin remediation.</li>
          </ul>

          <h2>4. Play Store Compliance Links</h2>
          <p>
            Direct links to all required Google Play Store compliance documents:
          </p>
          <ul>
            <li><Link to="/privacy"><strong>Privacy Policy</strong></Link> — Zero tracking, local encryption, permission transparency.</li>
            <li><Link to="/terms"><strong>Terms of Service</strong></Link> — Decentralized relay network agreement and honest delivery disclaimers.</li>
            <li><Link to="/data-safety"><strong>Google Play Data Safety Disclosure</strong></Link> — Question-by-question mapping for Play Console reviewers.</li>
            <li><Link to="/deletion"><strong>Account &amp; Data Deletion Policy</strong></Link> — Instructions for immediate local wipe and server buffer purge.</li>
          </ul>

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
