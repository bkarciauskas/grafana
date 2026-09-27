# verify-grafana feature map

Each file covers one user-facing feature: what it is, how a user reaches it, how to drive it with the Playwright harness (`scripts/drive.sh` + `@grafana/plugin-e2e`), and what end state proves it works. This map is the source for what "verified" means. A proof that drives one convenient entry point is incomplete when the file lists others.

| Feature                                                      | File                                         | Proof spec                                                              | Slices it guards (see project architecture doc)            |
| ------------------------------------------------------------ | -------------------------------------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------- |
| Dashboard editing: create, add panel, save                   | [dashboard-editing.md](dashboard-editing.md) | `specs/dashboard-create-save.spec.ts` ✅                                | S3 legacy model/components, S4 variables, S7 query editors |
| Dashboard viewing: time range, variables, view/inspect/share | [dashboard-viewing.md](dashboard-viewing.md) | none yet (reuse `e2e-playwright/dashboards-suite/*`)                    | S3, S4, S8 routing                                         |
| Browse, search, import dashboards                            | [browse-and-import.md](browse-and-import.md) | none yet (reuse `dashboard-browse.spec.ts`, `import-dashboard.spec.ts`) | S3 API layer, S8                                           |
| Explore: query, split panes, URL state, history              | [explore.md](explore.md)                     | `specs/explore-query-and-split.spec.ts` ✅                              | S5 Explore state, S6 TraceView, S7                         |
| Data sources (Connections) CRUD                              | [datasources.md](datasources.md)             | none yet                                                                | S2 CRUD pages to RTK Query                                 |

✅ = executed green against a `launch.sh` instance.

Not mapped yet (add when a slice touches them): alerting (`/alerting/list`), admin users/teams/orgs (`/admin/users`, `/org/teams`; S2), plugin catalog (`/plugins`), profile/preferences (`/profile`).

Adding a feature: create `<feature>.md` with the four H2s `Sub-features`, `How to get to it (user POV)`, `Driving it with Playwright`, `Gotchas`. Add a row here, and add a spec under `specs/` once you have driven it.
