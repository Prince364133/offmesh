import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'OffMesh Documentation',
  tagline: 'Stay Connected. Anywhere. — Decentralized Offline Smartphone Messaging & Opportunistic Store-and-Forward Mesh',
  favicon: 'img/favicon.ico',

  url: 'https://offmesh.docs.local',
  baseUrl: '/',

  organizationName: 'offmesh',
  projectName: 'offmesh-docs',

  onBrokenLinks: 'warn',

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
      defaultMode: 'dark',
      disableSwitch: false,
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'OffMesh',
      logo: {
        alt: 'OffMesh Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'tutorialSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          href: 'http://localhost:3000/docs',
          label: 'Interactive Swagger UI',
          position: 'left',
        },
        {
          href: 'https://github.com/Prince364133/offline-messaging',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Architecture & Design',
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
              label: 'UI/UX Design System',
              to: '/docs/ui-ux/design-system',
            },
          ],
        },
        {
          title: 'Specifications',
          items: [
            {
              label: 'Cryptographic Protocols',
              to: '/docs/specifications/cryptography',
            },
            {
              label: 'Microsecond Merkle Sync',
              to: '/docs/specifications/merkle-sync',
            },
            {
              label: 'Honest Delivery Statuses',
              to: '/docs/ui-ux/honest-statuses',
            },
          ],
        },
        {
          title: 'Validation & Roadmap',
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
              label: 'Platform Status & Milestones',
              to: '/docs/empirical-validation/status',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} NearLink Decentralized Mesh Project. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['powershell', 'bash', 'java', 'dart', 'json'],
    },
  },
};

export default config;
