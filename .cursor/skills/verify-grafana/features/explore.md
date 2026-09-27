# Explore

Ad-hoc querying without a dashboard (`features/explore`). This area still uses classic Redux (`createAction` reducers, `connect()` HOCs, class components such as `Explore.tsx`), which makes it a main target of modernization slice S5. Pane state round-trips through the URL, and shared links depend on that.

## Sub-features

- Query editor rows for the selected datasource. Run with the refresh picker Run button or `shift+enter`.
- Results: Graph (uPlot), Table, Logs, Traces (TraceView, a forked Jaeger UI), and Node graph, depending on the frames returned.
- Split view: two panes, each with its own datasource, queries, and time range. Toolbar Split / Close.
- URL state: `/explore?schemaVersion=1&panes={"<id>":{"datasource":...,"queries":[...],"range":{...}}}`.
- Query history drawer (toolbar or "Query history" button), content outline, query inspector.
- "Add" → add to dashboard (creates a panel on a new or existing dashboard), and create a correlation.
- Time picker in the toolbar (`selectors.components.TimePicker.moveBackwardButton` etc.).

## How to get to it (user POV)

Mega menu Explore (`/explore`), or a panel menu → Explore on a dashboard. The default datasource (gdev-testdata) is preselected.

## Driving it with Playwright

Proof spec: `specs/explore-query-and-split.spec.ts` (green). Run it with `scripts/drive.sh explore-query-and-split`. It opens `/explore`, picks the TestData scenario "CSV Metric Values", runs the query, splits the pane, and reloads the split URL.

```ts
const panes = dashboardPage.getByGrafanaSelector(selectors.pages.Explore.General.container); // one per pane
const scenario = dashboardPage.getByGrafanaSelector(
  selectors.components.DataSource.TestData.QueryTab.scenarioSelectContainer
);
await scenario.locator('input[id*="test-data-scenario-select-"]').click();
await page.getByText('CSV Metric Values', { exact: true }).click();
const resp = page.waitForResponse((r) => r.url().includes('/api/ds/query') && r.request().method() === 'POST');
await dashboardPage.getByGrafanaSelector(selectors.components.RefreshPicker.runButtonV2).first().click();
await dashboardPage.getByGrafanaSelector(selectors.pages.Explore.toolbar.split).click();
await expect(panes).toHaveCount(2);
```

Other handles: `selectors.pages.Explore.toolbar.{bar,split,addTo,share,copyLink}`, `selectors.pages.Explore.QueryHistory.container`, and `selectors.components.Panels.Panel.title('Graph' | 'Table')` for the result sections. Repo spec to reuse: `VERIFY_SPEC_DIR=e2e-playwright/various-suite drive.sh explore.spec.ts` (green against this instance). Related specs: `query-editor.spec.ts`, `recent-queries.spec.ts`, `trace-view-scrolling.spec.ts`.

Proof end state:

- The `/api/ds/query` response is 200 and `results.A.frames` is non-empty. The request body has the expected `scenarioId` and datasource uid `PD8C576611E62080A`.
- The Graph panel is visible with a `canvas`.
- The URL `panes=` contains the query (poll for it).
- Opening that URL fresh restores the same number of panes with results.

## Gotchas

- URL sync is asynchronous. Use `expect.poll(() => decodeURIComponent(page.url()))`.
- In split view each pane has its own Run button, so use `.first()` or scope to a pane container.
- The datasource picker input is empty and the datasource shows as a logo (`getByRole('img', { name: 'TestData logo' })`).
- Logs, traces, and prometheus features need the devenv docker datasources. TestData covers graph/table, and also logs and traces via its scenarios ("Logs", "Trace") without docker.
