# Dashboard viewing

Opening a saved dashboard and interacting with it without editing: time range, refresh, template variables, panel view/inspect, and sharing.

## Sub-features

- Time picker: relative/absolute ranges, shift back/forward, zoom out, time zone. The range is kept in the URL (`from`/`to`).
- Refresh picker: manual refresh and auto-refresh interval.
- Template variables in the submenu. Values are kept in the URL (`var-<name>=`).
- Panel menu: View (`viewPanel=`), Inspect (Data / Query / JSON drawer), Explore, Share.
- Share drawer: link, embed, snapshot, export JSON/image.
- Solo panel route `/d-solo/<uid>/<slug>?panelId=`.
- Kiosk mode (`?kiosk`).

## How to get to it (user POV)

Mega menu Dashboards → open a dashboard (for example from the "gdev dashboards" folder), or go to `/d/<uid>/<slug>`. Time and refresh controls are at the top right. Variables are in the row under the toolbar. The panel menu appears when you hover a panel title.

## Driving it with Playwright

No dedicated spec yet. Reuse the repo e2e specs against the launched instance:

```bash
VERIFY_SPEC_DIR=e2e-playwright/dashboards-suite .cursor/skills/verify-grafana/scripts/drive.sh dashboard-timepicker.spec.ts
VERIFY_SPEC_DIR=e2e-playwright/dashboards-suite .cursor/skills/verify-grafana/scripts/drive.sh dashboard-view-panel.spec.ts
VERIFY_SPEC_DIR=e2e-playwright/dashboards-suite .cursor/skills/verify-grafana/scripts/drive.sh dashboard-templating.spec.ts
VERIFY_SPEC_DIR=e2e-playwright/various-suite     .cursor/skills/verify-grafana/scripts/drive.sh inspect-drawer.spec.ts
```

Useful handles:

- `gotoDashboardPage({ uid, queryParams: new URLSearchParams({ from: 'now-1h', to: 'now' }) })`
- Time picker: `selectors.components.TimePicker.openButton`, `.fromField`, `.toField`, `.applyTimeRange`.
- Refresh: `selectors.components.RefreshPicker.runButtonV2`.
- Panels: `selectors.components.Panels.Panel.title(title)` and `.menu(title)`.
- Variables: `selectors.pages.Dashboard.SubMenu.submenuItemLabels(label)`.

Proof end state: the URL carries the new state (`from`/`to`, `var-*`, `viewPanel`), and a `/api/ds/query` request is issued with the new range or variable value. Assert the request body, not just the label text. Reloading the URL restores the same view.

## Gotchas

- Many dashboards-suite specs import JSON from `e2e-playwright/dashboards/*.json` or rely on provisioned `devenv/dev-dashboards`. Both are available because `launch.sh` provisions `devenv/dashboards.yaml`.
- Dashboards whose panels use prometheus, loki, or influx show errors unless `make devenv sources=...` is running. Pick TestData-backed dashboards for proofs.
- Image export and rendering need the image renderer (`START_IMAGE_RENDERER` in the e2e harness), which is not started here.
