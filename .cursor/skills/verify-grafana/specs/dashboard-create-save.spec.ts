import { test, expect } from '@grafana/plugin-e2e';

import { snap } from './evidence';

test('Dashboards: create a dashboard with a TestData panel, save it, and reload it from the server', async ({
  page,
  selectors,
  gotoDashboardPage,
  request,
}) => {
  const title = `verify-dashboard-${Date.now()}`;
  const panelTitle = 'Verify panel';

  const dashboardPage = await gotoDashboardPage({});
  const panelEditPage = await dashboardPage.addPanel();
  await panelEditPage.setVisualization('Time series');
  await panelEditPage.setPanelTitle(panelTitle);
  await panelEditPage.refreshPanel();
  await expect(page.locator('canvas').first()).toBeVisible();
  await snap(page, 'panel-editor-with-data');

  await panelEditPage.backToDashboard();
  await dashboardPage.getByGrafanaSelector(selectors.components.NavToolbar.editDashboard.saveButton).click();
  await page.getByTestId(selectors.components.Drawer.DashboardSaveDrawer.saveAsTitleInput).fill(title);
  await snap(page, 'save-drawer');
  await dashboardPage.getByGrafanaSelector(selectors.components.Drawer.DashboardSaveDrawer.saveButton).click();
  await expect(page.getByRole('status', { name: 'Dashboard saved' })).toBeVisible();
  await expect(page).toHaveURL(/\/d\/[^/]+\//);
  const uid = new URL(page.url()).pathname.split('/')[2];

  const saved = await request.get(`/api/dashboards/uid/${uid}`);
  expect(saved.status()).toBe(200);
  const json = await saved.json();
  expect(json.dashboard.title).toBe(title);
  expect(json.dashboard.panels.map((p: { title: string }) => p.title)).toContain(panelTitle);

  await page.goto(`/d/${uid}`);
  await expect(dashboardPage.getByGrafanaSelector(selectors.components.Panels.Panel.title(panelTitle))).toBeVisible();
  await expect(page.getByText(title).first()).toBeVisible();
  await expect(page.locator('canvas').first()).toBeVisible();
  await snap(page, 'dashboard-reloaded');
});
