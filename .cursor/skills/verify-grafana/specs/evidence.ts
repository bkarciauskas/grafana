import { type Page } from '@playwright/test';
import path from 'path';

let step = 0;

/** Full-page screenshot into $VERIFY_EVIDENCE_DIR/screenshots/NN-<name>.png, numbered in call order. */
export async function snap(page: Page, name: string) {
  step += 1;
  const file = path.join(
    process.env.VERIFY_EVIDENCE_DIR ?? 'test-results',
    'screenshots',
    `${String(step).padStart(2, '0')}-${name}.png`
  );
  await page.screenshot({ path: file, fullPage: true });
  return file;
}
