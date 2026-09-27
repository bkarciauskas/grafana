import { test, expect } from '@grafana/plugin-e2e';

import { snap } from './evidence';

const TESTDATA_UID = 'PD8C576611E62080A'; // gdev-testdata, provisioned by launch.sh

test('Explore: run a TestData query, split the pane, and restore both panes from the URL', async ({
  page,
  selectors,
  dashboardPage,
}) => {
  const byGrafana = dashboardPage.getByGrafanaSelector.bind(dashboardPage);
  const panes = byGrafana(selectors.pages.Explore.General.container);

  await page.goto('/explore');
  await expect(panes).toHaveCount(1);
  // The picker shows the default datasource as a logo, not as input text.
  await expect(page.getByRole('img', { name: 'TestData logo' }).first()).toBeVisible();
  await snap(page, 'explore-opened');

  const scenario = byGrafana(selectors.components.DataSource.TestData.QueryTab.scenarioSelectContainer);
  await scenario.locator('input[id*="test-data-scenario-select-"]').click();
  await page.getByText('CSV Metric Values', { exact: true }).click();

  const queryResponse = page.waitForResponse(
    (r) => r.url().includes('/api/ds/query') && r.request().method() === 'POST'
  );
  await byGrafana(selectors.components.RefreshPicker.runButtonV2).first().click();
  const response = await queryResponse;
  expect(response.status()).toBe(200);
  const body = await response.json();
  expect(body.results.A.frames.length).toBeGreaterThan(0);
  expect(response.request().postDataJSON().queries[0]).toMatchObject({
    scenarioId: 'csv_metric_values',
    datasource: { uid: TESTDATA_UID },
  });

  await expect(byGrafana(selectors.components.Panels.Panel.title('Graph'))).toBeVisible();
  await expect(page.locator('canvas').first()).toBeVisible();
  await snap(page, 'query-result-graph');

  // Explore syncs pane state to the URL asynchronously after the query runs.
  await expect.poll(() => decodeURIComponent(page.url())).toContain('csv_metric_values');

  await byGrafana(selectors.pages.Explore.toolbar.split).click();
  await expect(panes).toHaveCount(2);
  await snap(page, 'split-two-panes');

  const splitUrl = page.url();
  await page.goto('/');
  await page.goto(splitUrl);
  await expect(panes).toHaveCount(2);
  await expect(byGrafana(selectors.components.Panels.Panel.title('Graph'))).toHaveCount(2);
  await snap(page, 'split-restored-from-url');
});
