import { defineConfig } from '@playwright/test';
import path, { dirname } from 'path';

import { type PluginOptions } from '@grafana/plugin-e2e';

import { baseConfig, withAuth } from '../../../playwright.config';

// Run through scripts/drive.sh, which sets these and points at an already-launched instance.
const evidenceDir = process.env.VERIFY_EVIDENCE_DIR;
if (!evidenceDir) {
  throw new Error('VERIFY_EVIDENCE_DIR is not set; run .cursor/skills/verify-grafana/scripts/drive.sh');
}

export default defineConfig<PluginOptions>({
  ...baseConfig,
  // No webServer: the instance comes from scripts/launch.sh.
  fullyParallel: false,
  workers: 1,
  retries: 0,
  outputDir: path.join(evidenceDir, 'test-results'),
  reporter: [
    ['list'],
    ['html', { outputFolder: path.join(evidenceDir, 'html-report'), open: 'never' }],
    ['json', { outputFile: path.join(evidenceDir, 'results.json') }],
  ],
  use: {
    ...baseConfig.use,
    baseURL: process.env.GRAFANA_URL,
    viewport: { width: 1600, height: 900 },
    screenshot: 'on',
    video: 'on',
    trace: 'on',
  },
  projects: [
    {
      name: 'authenticate',
      testDir: `${dirname(require.resolve('@grafana/plugin-e2e'))}/auth`,
      testMatch: [/.*\.js/],
    },
    withAuth({
      name: 'verify',
      testDir: process.env.VERIFY_SPEC_DIR ?? path.join(__dirname, 'specs'),
    }),
  ],
});
