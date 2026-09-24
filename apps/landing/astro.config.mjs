import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: process.env.SITE_URL || 'https://offmesh.pages.dev',
  output: 'static',
  integrations: [sitemap()],
  server: {
    port: 4321,
    host: true
  }
});
