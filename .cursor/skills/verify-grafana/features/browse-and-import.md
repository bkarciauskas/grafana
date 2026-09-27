# Browse, search, and import dashboards

The dashboards browser (`features/browse-dashboards`: folders, move/delete, new folder), search (`features/search`, command palette), and importing dashboard JSON (`features/manage-dashboards`).

## Sub-features

- Browse tree at `/dashboards`: expand folders, open dashboards, select via checkboxes, move, delete.
- New folder (`/dashboards` → New → New folder), folder view `/dashboards/f/<uid>/<slug>`.
- Search: the top bar "Search..." box / `ctrl+k` command palette, and the list view with tag and starred filters.
- Import: `/dashboard/import`, by pasting JSON or entering a grafana.com ID, then pick folder and datasource mappings.
- Starring a dashboard (star icon on the dashboard toolbar). Starred dashboards show in the mega menu "Starred".

## How to get to it (user POV)

Mega menu Dashboards opens `/dashboards`. From there, New → New folder / Import. Search from the top bar anywhere in the app.

## Driving it with Playwright

No dedicated spec yet. Reuse the repo e2e specs:

```bash
VERIFY_SPEC_DIR=e2e-playwright/dashboards-suite .cursor/skills/verify-grafana/scripts/drive.sh dashboard-browse.spec.ts
VERIFY_SPEC_DIR=e2e-playwright/dashboards-suite .cursor/skills/verify-grafana/scripts/drive.sh import-dashboard.spec.ts
VERIFY_SPEC_DIR=e2e-playwright/various-suite     .cursor/skills/verify-grafana/scripts/drive.sh bookmarks.spec.ts
```

Handles:

- Table: `selectors.pages.BrowseDashboards.table.body`, `.row(name)`, `.checkbox(uid)`.
- New folder: `selectors.pages.BrowseDashboards.NewFolderForm.nameInput` and `.createButton`.
- Import: `selectors.components.DashboardImportPage.textarea` → `.submit`, then `selectors.components.ImportDashboardForm.name` → `.submit`.
- Search results: `selectors.pages.SearchDashboards.table`.

Proof end state:

- The browse row for the new dashboard or folder is visible.
- `GET /api/search?query=<title>` (or `GET /apis/folder.grafana.app/v1beta1/namespaces/default/folders`) returns the object.
- After import, the URL is `/d/<uid>/...` and the imported panels render.

## Gotchas

- Search is backed by unified search (`data/unified-search` in the run dir). Newly saved dashboards can take a moment to appear, so use `expect.poll` on `/api/search`.
- The "gdev dashboards" folder is provisioned and read-only for moves and deletes. Create your own folder for mutation tests.
