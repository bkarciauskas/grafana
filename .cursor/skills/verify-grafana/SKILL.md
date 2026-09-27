---
name: verify-grafana
description: Launch this Grafana checkout locally (backend `make run` + frontend `yarn start`, admin/admin, embedded SQLite), check it with a doctor script, drive the web UI with the repo's Playwright + @grafana/plugin-e2e harness, and capture screenshot/video/trace evidence. Use to prove a change (e.g. a modernization slice) works end to end in the real UI, or to check an HTTP API behavior against a running server.
---

# verify-grafana

Primary surface: the **web UI** at `http://localhost:3000` (login `admin` / `admin`).
Secondary surface: the **HTTP API** on the same port (`/api/*` legacy REST, `/apis/<group>/<version>/...` App Platform), basic auth `admin:admin`.

All helpers live in `.cursor/skills/verify-grafana/scripts/` and run from any cwd. Feature recipes live in `features/` (start at `features/README.md`).

| Path                          | What it is                                                                                            |
| ----------------------------- | ----------------------------------------------------------------------------------------------------- |
| `scripts/launch.sh`           | start backend + frontend in tmux, wait until ready                                                    |
| `scripts/doctor.sh`           | read-only health check; exit 0 = worth driving                                                        |
| `scripts/drive.sh`            | run a Playwright spec, write evidence to a new folder                                                 |
| `scripts/cleanup.sh`          | stop what launch started, delete scratch state (keeps evidence)                                       |
| `playwright.verify.config.ts` | extends the repo's `playwright.config.ts` `baseConfig`; screenshots, video, trace always on; 1600x900 |
| `specs/*.spec.ts`             | proof specs (`evidence.ts` provides `snap()` for numbered step screenshots)                           |

## Prerequisites (once per VM)

- Node from `.nvmrc` (v24.11.0). `lib.sh` prepends `~/.nvm/versions/node/v24.11.0/bin` to `PATH` because some VMs put an older `node` first (e.g. `/exec-daemon/node` v22). If missing: `nvm install`.
- `corepack enable`; `yarn install --immutable` (~35 s with a warm cache). Yarn version comes from `.yarnrc.yml` (4.17.x), not what AGENTS.md says.
- Playwright browser: `yarn playwright install chromium` (~10 s).
- Go (per `go.mod`) and gcc; `lsof` (used for port ownership; falls back to `ss`).

## Launch

```bash
.cursor/skills/verify-grafana/scripts/launch.sh             # backend + frontend (normal)
.cursor/skills/verify-grafana/scripts/launch.sh --backend-only   # backend-only change and public/build already current
VERIFY_PORT=3100 .cursor/skills/verify-grafana/scripts/launch.sh  # if :3000 is taken by someone else
```

What it does:

- Refuses to start if tmux sessions `verify-grafana-backend` / `verify-grafana-frontend` exist, if the port is already listening, or if `/tmp/verify-grafana/state.env` is left over. **Do not double-drive**: `make run` (air) writes `./bin/grafana-air` and `yarn start` writes `public/build`, so only one instance per checkout is possible even on another port. If a session exists, run `doctor.sh` and reuse it, or `cleanup.sh` first.
- Isolated state under `$VERIFY_RUN_DIR` (default `/tmp/verify-grafana`): SQLite `data/grafana.db`, `logs/`, `plugins/`, `provisioning/` via `GF_PATHS_*` env vars. The repo's `data/` and `conf/` are not touched.
- Provisions the same datasources/dashboards as the e2e harness: `devenv/datasources.yaml` (default datasource **gdev-testdata**, uid `PD8C576611E62080A`; the others point at docker services that are not running, so only TestData returns data) and `devenv/dashboards.yaml` (folder "gdev dashboards" from `devenv/dev-dashboards`).
- Backend: `make run` in tmux `verify-grafana-backend`, log `/tmp/verify-grafana/backend.log`. Air hot-reloads Go/ini/html/json changes under `apps conf pkg public/views`.
- Frontend: `yarn start` (webpack `--watch`, no port) in tmux `verify-grafana-frontend`, log `/tmp/verify-grafana/frontend.log`. It writes `public/build`; the backend serves it.

Ready when the script prints `backend healthy after Ns`. It waits for `compiled successfully|with` in the frontend log, then `GET /api/health` = 200. Measured on a cloud VM: webpack first compile ~90 s, whole launch ~2m45s (backend build overlaps). A cold Go cache can make the first backend build take 3-6 min. Timeouts: 15 min frontend, 25 min backend.

Watch live: `tmux attach -t verify-grafana-backend` (detach `Ctrl-b d`). After editing frontend code, wait for a new `compiled` line in `frontend.log` before driving. After editing Go, wait for air's rebuild and `/api/health`.

## Doctor

```bash
.cursor/skills/verify-grafana/scripts/doctor.sh   # prints ok/FAIL/warn lines, then HEALTHY or UNHEALTHY
```

Read-only. It checks: both tmux panes alive; the last webpack compile had no errors; the port listener is a descendant of our backend pane (so we are not driving someone else's Grafana); `/api/health` reports `database: ok`; the build commit matches checkout HEAD (a warning only, since air rebuilds uncommitted edits); `admin:admin` works on `/api/user`; `/login` references a `public/build/*.js` bundle that is actually served; gdev-testdata exists. Run it first whenever anything looks off, and before every drive session you didn't just launch.

## Drive

```bash
.cursor/skills/verify-grafana/scripts/drive.sh explore-query-and-split      # specs/explore-query-and-split.spec.ts
.cursor/skills/verify-grafana/scripts/drive.sh dashboard-create-save
.cursor/skills/verify-grafana/scripts/drive.sh dashboard-create-save --headed --debug   # extra args go to playwright
VERIFY_SPEC_DIR=e2e-playwright/various-suite .cursor/skills/verify-grafana/scripts/drive.sh explore.spec.ts   # reuse a repo e2e spec
```

The first argument is a Playwright file filter. The run goes through the `authenticate` project from `@grafana/plugin-e2e` (logs in as admin/admin, storage state in `playwright/.auth/admin.json`, gitignored), then the `verify` project. The last output line is the evidence folder. Exit code = Playwright's.

Writing a new proof spec: put it in `specs/<feature>-<behavior>.spec.ts` and follow the two existing specs.

- Import `test, expect` from `@grafana/plugin-e2e` for the fixtures: `page`, `selectors`, `dashboardPage`, `gotoDashboardPage`, `createDataSourceConfigPage`, `explorePage`, `request` (already authenticated as admin).
- Locate with `dashboardPage.getByGrafanaSelector(selectors.<path>)`. Selectors are defined in `packages/grafana-e2e-selectors/src/selectors/{pages,components}.ts`. If an element has no selector, add one there (see the repo skill `.claude/skills/add-e2e-selectors`) rather than using CSS classes or nth-child. After that, prefer ARIA roles/labels (`getByRole('status', { name: 'Dashboard saved' })`) and route paths (`/explore`, `/dashboard/new`, `/d/<uid>`).
- Call `snap(page, 'step-name')` after each meaningful action.
- Assert side effects: capture the network response (`page.waitForResponse(r => r.url().includes('/api/ds/query'))`) and/or re-read state through the API (`request.get('/api/dashboards/uid/<uid>')`).
- More recipes: `e2e-playwright/**` (205 specs), e.g. `e2e-playwright/dashboard-new-layouts/utils.ts` and `e2e-playwright/utils/dashboard-helpers.ts`.

Secondary surface: HTTP API with curl.

```bash
curl -s -u admin:admin localhost:3000/api/health
curl -s -u admin:admin -H 'Content-Type: application/json' localhost:3000/api/ds/query \
  -d '{"from":"now-1h","to":"now","queries":[{"refId":"A","datasource":{"uid":"PD8C576611E62080A"},"scenarioId":"csv_metric_values","stringInput":"1,2,3"}]}'
curl -s -u admin:admin "localhost:3000/api/search?query=<title>"
curl -s -u admin:admin localhost:3000/api/dashboards/uid/<uid>
curl -s -u admin:admin localhost:3000/apis/dashboard.grafana.app/v1/namespaces/default/dashboards
```

For API evidence, save the command and response body into the run's evidence folder (for example `> "$EVIDENCE/api-<name>.json"`).

## Evidence

Every `drive.sh` run writes to a new folder `$VERIFY_EVIDENCE_ROOT/<UTC-timestamp>-<spec>/`. The default root is `~/verify-grafana-evidence/`, outside the repo and outside the scratch dir, so cleanup never deletes it.

```
run-info.txt            spec, url, git HEAD, dirty file count, /api/health, exit_code
playwright.log          console output
screenshots/NN-*.png    step screenshots from snap(), in order
test-results/<test>/    video.webm, trace.zip (open with `yarn playwright show-trace <path>`), final screenshot
html-report/            Playwright HTML report
results.json            machine-readable results
```

Proof standards:

- Drive the real user path: UI routes and clicks the way a user would, against the real backend and real SQLite. Don't call internal setters, Redux dispatches, or test-only endpoints. Using the API to _set up_ preconditions or _read back_ results is fine; using it to perform the behavior under test is not.
- Capture the action and the resulting state, not only the final screen. Numbered `snap()` screenshots plus video cover this.
- Verify side effects together with what's visible: the query request/response (`/api/ds/query`), the persisted object (`/api/dashboards/uid/...`), URL state (Explore `panes=`).
- No mocks. TestData is Grafana's built-in datasource, so it is not a mock of anything. Other devenv datasources need `make devenv sources=...` (docker); without it, don't claim anything about them.
- Report the evidence folder path and the `exit_code` line from `run-info.txt`. A failed run is still evidence: `test-results/` has the failure screenshot, `error-context.md` (an ARIA snapshot of the page), and the trace.

## Cleanup

```bash
.cursor/skills/verify-grafana/scripts/cleanup.sh
```

Kills only what `launch.sh` started. It collects the full process tree under the two recorded tmux pane PIDs plus the port listener PID recorded at launch. air runs `grafana-air` in its own session, so a process-group kill would miss it. It sends SIGTERM, then SIGKILL after 15 s. Then it kills the two tmux sessions and removes `$VERIFY_RUN_DIR`. It never kills by process name and never touches `~/verify-grafana-evidence/`, the repo `data/`, `bin/`, or `public/build`. Run it after every attempt, including failed launches, so the next `launch.sh` preflight passes. Afterwards `lsof -iTCP:3000 -sTCP:LISTEN` should print nothing; the script warns if something is still listening.

## Gotchas

- `make run` also starts pprof on `127.0.0.1:6000` (from `.air.toml`), so a second backend on this VM will fail even on a different `VERIFY_PORT`.
- On a fresh plugins dir, the backend downloads preinstalled plugins (e.g. opentsdb) from grafana.com in the background. Offline VMs log errors for these; that's harmless for core features.
- `/api/health` can answer before provisioning finishes. If gdev-testdata is missing right after launch, re-run doctor a few seconds later.
- Explore writes pane state to the URL asynchronously. Poll (`expect.poll(() => page.url())`) instead of reading it right after an action.
- The datasource picker shows the current datasource as a logo plus an empty input, not as input text.
