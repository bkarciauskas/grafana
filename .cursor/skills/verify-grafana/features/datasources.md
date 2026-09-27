# Data sources (Connections)

Listing, adding, configuring, testing, and deleting data sources (`features/datasources`, `features/connections`). These are classic CRUD pages built on createSlice + thunks + `getBackendSrv()` + `connect()`, and they are candidates for slice S2 (RTK Query).

## Sub-features

- List: `/connections/datasources` (legacy `/datasources` redirects here), with a search filter.
- Add: `/connections/datasources/new` → pick plugin → settings page.
- Edit: `/connections/datasources/edit/<uid>` (name, default toggle, plugin-specific settings), "Save & test", Delete.
- Dashboards tab: `/connections/datasources/edit/<uid>/dashboards` (bundled dashboards to import).
- Provisioned data sources (all `gdev-*`) are read-only and show a read-only message.

## How to get to it (user POV)

Mega menu Connections → Data sources. "Add new data source" button → choose e.g. "TestData" → Save & test.

## Driving it with Playwright

No dedicated spec yet. The plugin-e2e fixture `createDataSourceConfigPage` creates the data source **through the API** and then opens its settings page. That's fine for proving the edit and "Save & test" path, but it skips the Add flow:

```ts
const configPage = await createDataSourceConfigPage({
  type: 'grafana-testdata-datasource',
  name: `verify-ds-${Date.now()}`,
});
await expect(await configPage.saveAndTest()).toBeOK(); // clicks Save & test, resolves with the health response
```

To prove the Add UI path, which is what an S2 rewrite of the list and add pages changes, click through it: `page.goto('/connections/datasources')` → `selectors.pages.DataSources.dataSourceAddButton` → `selectors.pages.AddDataSource.dataSourcePluginsV2('TestData')` → `selectors.pages.DataSource.saveAndTest`.

UI handles:

- List: `selectors.pages.DataSources.dataSourceAddButton` and `.dataSources(name)`.
- Add: `selectors.pages.AddDataSource.dataSourcePluginsV2('TestData')`.
- Settings: `selectors.pages.DataSource.name`, `.saveAndTest`, `.alert`, `.delete`, `.readOnly`.

Existing repo specs that go through data source config: `e2e-playwright/various-suite/prometheus-config.spec.ts` and `exemplars.spec.ts`. These need prometheus for "test" to pass, so they are not usable without devenv.

Proof end state:

- After Save & test, `selectors.pages.DataSource.alert` shows success.
- `GET /api/datasources/name/<name>` returns it.
- It appears in the list and in the Explore datasource picker.
- For delete: the confirm modal, then `GET /api/datasources/name/<name>` returns 404.

## Gotchas

- Opening a provisioned `gdev-*` data source shows `selectors.pages.DataSource.readOnly` with no Save button. Create your own for edit and delete proofs.
- Most non-TestData plugins fail "test" without their backing service (`make devenv sources=...`).
- `createDataSourceConfigPage` deletes the data source after the test by default (`deleteDataSourceAfterTest: false` keeps it).
