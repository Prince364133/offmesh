import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'OffMesh',
  tagline: 'Off-Grid, Delay-Tolerant Encrypted Mesh Messenger',
  favicon: 'img/favicon.ico',

  url: 'https://offmesh.simplicion.com',
  baseUrl: '/',

  organizationName: 'Simplicion Private Limited',
  projectName: 'offmesh',

  onBrokenLinks: 'warn',
  onBrokenAnchors: 'ignore',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    colorMode: {
      defaultMode: 'light',
      disableSwitch: false,
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'OffMesh',
      logo: {
        alt: 'OffMesh Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          to: '/#features',
          label: 'Features',
          position: 'left',
        },
        {
          to: '/#delivery-states',
          label: 'Delivery States',
          position: 'left',
        },
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          type: 'dropdown',
          label: 'Play Store Compliance',
          position: 'left',
          items: [
            {
              to: '/privacy',
              label: 'Privacy Policy',
            },
            {
              to: '/terms',
              label: 'Terms of Service',
            },
            {
              to: '/data-safety',
              label: 'Google Play Data Safety',
            },
            {
              to: '/deletion',
              label: 'Account & Data Deletion',
            },
            {
              to: '/contact',
              label: 'Developer Details & Contact',
            },
          ],
        },
        {
          to: '/#download',
          label: 'Download APK',
          position: 'right',
          className: 'button button--primary button--sm navbar-download-btn',
        },
        {
          href: 'https://github.com/Prince364133/offline-messaging',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'light',
      links: [
        {
          title: 'Play Store Compliance & Legal',
          items: [
            {
              label: 'Privacy Policy',
              to: '/privacy',
            },
            {
              label: 'Terms of Service',
              to: '/terms',
            },
            {
              label: 'Google Play Data Safety Disclosure',
              to: '/data-safety',
            },
            {
              label: 'Account & Data Deletion Instructions',
              to: '/deletion',
            },
            {
              label: 'Developer & Corporate Contact',
              to: '/contact',
            },
          ],
        },
        {
          title: 'Architecture & Protocols',
          items: [
            {
              label: 'High-Level Design (HLD)',
              to: '/docs/architecture/hld',
            },
            {
              label: 'Low-Level Design (LLD)',
              to: '/docs/architecture/lld',
            },
            {
              label: 'Cryptographic Protocols',
              to: '/docs/specifications/cryptography',
            },
            {
              label: 'Microsecond Merkle Sync',
              to: '/docs/specifications/merkle-sync',
            },
          ],
        },
        {
          title: 'UI/UX & Design System',
          items: [
            {
              label: 'Monochrome Minimal Design System',
              to: '/docs/ui-ux/design-system',
            },
            {
              label: 'Honest Delivery Status Badges',
              to: '/docs/ui-ux/honest-statuses',
            },
            {
              label: 'Product UI/UX Principles',
              to: '/docs/ui-ux/product-principles',
            },
            {
              label: 'Screen Inventory Spec',
              to: '/docs/ui-ux/screen-inventory-spec',
            },
          ],
        },
        {
          title: 'Validation & Downloads',
          items: [
            {
              label: 'Automated Test Matrix (35/35)',
              to: '/docs/empirical-validation/test-suite-matrix',
            },
            {
              label: 'Experiment Log (E-01–E-07)',
              to: '/docs/empirical-validation/experiment-log',
            },
            {
              label: 'Direct APK Download (v1.0.1+2)',
              href: 'pathname:///downloads/offmesh-v1.0.1.apk',
            },
            {
              label: 'Google Play Release AAB',
              href: 'pathname:///downloads/offmesh-v1.0.1.aab',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Simplicion Private Limited. OffMesh™ is a registered product of Simplicion Private Limited (New Delhi, India). Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['powershell', 'bash', 'java', 'dart', 'json'],
    },
  },
};

export default config;
