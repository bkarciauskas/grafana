# Dashboard editing

Create a dashboard, add and configure panels (datasource, query, visualization, title), and save. Rendering is `features/dashboard-scene` (Scenes). It still loads the legacy `DashboardModel` to migrate saved JSON, and panel editing reuses `features/dashboard/components/PanelEditor`.

## Sub-features

- New dashboard → add visualization → panel editor (query rows, viz picker, options pane) → back to dashboard → save drawer (title, folder) → saved at `/d/<uid>/<slug>`.
- Edit an existing dashboard: `Edit` button → change → save (the save drawer shows a diff tab).
- Dashboard settings: `/d/<uid>?editview=settings` (general, variables, links, JSON model, versions).
- Variables editor: settings → Variables → New variable (query, custom, constant, textbox, interval, datasource).
- Rows, repeats, library panels.
- New layouts (tabs, auto-grid, side edit pane) exist only with the `dashboardNewLayouts` feature toggle, which is off by default here. To test them, add `GF_FEATURE_TOGGLES_ENABLE=dashboardNewLayouts` to the env in `launch.sh`.

## How to get to it (user POV)

Top bar `+` (New) → New dashboard, or the mega menu Dashboards → New → New dashboard. The route is `/dashboard/new`. Then "Add visualization", pick the datasource (gdev-testdata is the default), and configure. Save with the toolbar Save button.

## Driving it with Playwright

Proof spec: `specs/dashboard-create-save.spec.ts` (green). Run it with `scripts/drive.sh dashboard-create-save`.

```ts
const dashboardPage = await gotoDashboardPage({}); // /dashboard/new
const panelEditPage = await dashboardPage.addPanel(); // handles old/new layouts
await panelEditPage.setVisualization('Time series');
await panelEditPage.setPanelTitle('Verify panel');
await panelEditPage.refreshPanel();
await panelEditPage.backToDashboard();
await dashboardPage.getByGrafanaSelector(selectors.components.NavToolbar.editDashboard.saveButton).click();
await page.getByTestId(selectors.components.Drawer.DashboardSaveDrawer.saveAsTitleInput).fill(title);
await dashboardPage.getByGrafanaSelector(selectors.components.Drawer.DashboardSaveDrawer.saveButton).click();
await expect(page.getByRole('status', { name: 'Dashboard saved' })).toBeVisible();
```

Proof end state:

- The URL matches `/d/<uid>/...`.
- `GET /api/dashboards/uid/<uid>` returns the title and a panel with the given title (`dashboard.panels[].title`).
- After a fresh `page.goto('/d/<uid>')`, `selectors.components.Panels.Panel.title('<panel title>')` is visible and a `canvas` (uPlot chart) renders.

For variables and editing an existing dashboard, reuse `e2e-playwright/dashboards-suite/new-*-variable.spec.ts` and `e2e-playwright/dashboard-new-layouts/utils.ts` (`saveDashboard`, `flows`).

## Gotchas

- A saved panel created this way has `targets: [{refId:'A'}]` and no explicit datasource, so it resolves to the default datasource at load time. If a slice changes default-datasource resolution, assert on the query request instead.
- Wait for `canvas` before the final screenshot. The panel chrome renders before the data arrives.
- The "Dashboard saved" toast can hide later toasts. Close it (`Close alert` button) if you save twice in one test.
- Provisioned "gdev dashboards" have `allowUiUpdates: false`. Test saving on dashboards you created, not on those.
