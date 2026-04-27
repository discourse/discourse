---
name: discourse-screenshots
description: Capture screenshots of the local Discourse site across the two core themes (Foundation, Horizon) and color modes (light, dark). Use when the user asks for "screenshots of themes", "light/dark mode shots", or similar.
---

# Discourse screenshots

Drives a system spec (`spec/system/theme_screenshots_spec.rb`) that boots a headless Playwright browser, cycles through the two core themes × color-mode matrix, and drops PNGs into `tmp/theme-screenshots/`.

## Matrix (default)

| Theme      | Theme ID | Modes       |
|------------|----------|-------------|
| Foundation | `-1`     | light, dark |
| Horizon    | `-2`     | light, dark |

Output is eight files by default — one per theme × mode × device: `desktop-foundation-light.png`, `mobile-foundation-light.png`, `desktop-foundation-dark.png`, `mobile-foundation-dark.png`, plus the matching four `*-horizon-*` files. When signed in, the role (`-user` / `-admin`) is inserted after the theme name (e.g. `mobile-horizon-admin-dark.png`). When capturing multiple paths, a path slug is also appended (e.g. `mobile-horizon-admin-dark-latest.png`).

## How to run

```bash
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 bin/rspec spec/system/theme_screenshots_spec.rb
```

Screenshots land in `tmp/theme-screenshots/`. `LOAD_PLUGINS=1` is always included so chat routes work.

### Arguments (env vars)

| Var                     | Default                      | Purpose                                                    |
|-------------------------|------------------------------|------------------------------------------------------------|
| `TAKE_SCREENSHOTS`      | *(unset — spec is skipped)*  | Must be `1` for the spec to run.                           |
| `LOAD_PLUGINS`          | `1`                          | Always set to `1` so chat and other plugin routes work.    |
| `SCREENSHOTS_DIR`       | `tmp/theme-screenshots`      | Where PNGs are written.                                    |
| `SCREENSHOTS_PATH`      | `/`                          | Single path to capture. Special sentinels: `/t/random` (random fabricated topic), `/my/*` (expanded to `/u/:username/*` for signed-in users). |
| `SCREENSHOTS_PATHS`     | *(unset)*                    | Comma-separated paths, or `all` for the full route list: `/latest`, `/categories`, `/groups`, `/admin`, `/my/summary`, `/chat`, `/new-topic`. Overrides `SCREENSHOTS_PATH` when set. `/admin` requires `SCREENSHOTS_AS=admin`; `/chat` and `/my/*` require `user` or `admin`; `/chat` also requires `LOAD_PLUGINS=1`. |
| `SCREENSHOTS_MODES`     | `light,dark`                 | Comma-separated color modes (`light`, `dark`).             |
| `SCREENSHOTS_AS`        | `anonymous`                  | Who to sign in as: `anonymous`, `user`, or `admin`.        |
| `SCREENSHOTS_DEVICES`   | `desktop,mobile`             | Comma-separated devices. Mobile uses Playwright's WebKit driver with an iPhone UA. |
| `SCREENSHOTS_THEMES`    | `foundation,horizon`         | Comma-separated built-in theme names to capture. Use `foundation` or `horizon` to restrict to one. |
| `SCREENSHOTS_THEME_URL` | *(unset)*                    | Git URL of a remote theme to install into the test DB and add to the matrix. Use `SCREENSHOTS_THEME_NAME` for the filename label (default: repo name). Set `SCREENSHOTS_THEMES=` (empty) to capture only the remote theme. |
| `SCREENSHOTS_THEME_ID`  | *(unset)*                    | ID of a theme already present in the test DB to add to the matrix. Use `SCREENSHOTS_THEME_NAME` to set its filename label. |
| `SCREENSHOTS_THEME_NAME`| repo name / `theme-<id>`     | Display name used in filenames for the extra theme.        |
| `SCREENSHOTS_BASELINE_DIR` | *(unset)*               | Path to a directory of previously captured screenshots. When set, the spec generates an HTML comparison pairing baseline PNGs against the current run's PNGs (matched by filename). Use for PR-vs-main comparisons. |
| `SCREENSHOTS_BASELINE_LABEL` | basename of dir       | Label shown in the HTML comparison for baseline screenshots. Defaults to the directory's basename. |

### Examples

```bash
# Default — all themes × light/dark × desktop/mobile at /
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 bin/rspec spec/system/theme_screenshots_spec.rb

# /categories page as admin, dark only, desktop only
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 SCREENSHOTS_PATH=/categories SCREENSHOTS_AS=admin \
  SCREENSHOTS_MODES=dark SCREENSHOTS_DEVICES=desktop \
  bin/rspec spec/system/theme_screenshots_spec.rb

# /chat and /latest with a remote theme alongside built-ins
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 \
  SCREENSHOTS_THEME_URL=https://github.com/org/my-theme \
  SCREENSHOTS_PATHS=/chat,/latest \
  bin/rspec spec/system/theme_screenshots_spec.rb

# Full route sweep as admin (all built-in themes, all modes)
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 SCREENSHOTS_PATHS=all SCREENSHOTS_AS=admin \
  bin/rspec spec/system/theme_screenshots_spec.rb

# Compare a remote theme against core themes on key screens (HTML output)
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 \
  SCREENSHOTS_THEME_URL=https://github.com/org/my-theme \
  SCREENSHOTS_THEME_NAME=my-theme \
  SCREENSHOTS_PATHS=/latest,/categories \
  bin/rspec spec/system/theme_screenshots_spec.rb
# → generates compare-desktop.html, compare-mobile.html

# PR vs main: step 1 — capture baseline on main branch
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 SCREENSHOTS_DIR=tmp/baseline SCREENSHOTS_PATHS=/latest,/categories \
  bin/rspec spec/system/theme_screenshots_spec.rb

# PR vs main: step 2 — capture current branch and generate HTML comparison
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 SCREENSHOTS_BASELINE_DIR=tmp/baseline \
  SCREENSHOTS_BASELINE_LABEL=main SCREENSHOTS_PATHS=/latest,/categories \
  bin/rspec spec/system/theme_screenshots_spec.rb
# → generates compare-desktop-vs-baseline.html, compare-mobile-vs-baseline.html
```

## Fabricated data

The spec creates the following data for richer screenshots:

- **2 categories** — "Announcements" and a second generic category
- **5 topics** spread across both categories with realistic titles
- **Chat channel** (if the Chat plugin is active) — "General" channel with 3 messages from admin and user, with both users added as members
- **2 DM channels** (if the Chat plugin is active) — admin↔user and admin↔user_2, each with a short back-and-forth conversation

## Invocation instructions

When this skill is invoked:

1. Build the command from `$ARGUMENTS`. If no arguments are given, use the default matrix.
2. Parse free-form args into env vars (composable — handle multiple at once):
   - "dark only" / "light only" → `SCREENSHOTS_MODES=…`
   - Any site-relative path — `on /X`, `at /X`, `/X page`, or a bare path → `SCREENSHOTS_PATH=…`
   - "a random topic" → `SCREENSHOTS_PATH=/t/random`
   - "as admin" / "as user" → `SCREENSHOTS_AS=…`
   - "desktop only" / "mobile only" → `SCREENSHOTS_DEVICES=…`
   - "foundation only" / "just horizon" / any built-in theme name → `SCREENSHOTS_THEMES=…` (comma-separated; values are `foundation` and/or `horizon`)
   - A git URL for a theme → `SCREENSHOTS_THEME_URL=…`; also set `SCREENSHOTS_THEME_NAME=<label>` if the user provides a name
   - A theme ID (e.g. "theme 42" / "theme ID 42") → `SCREENSHOTS_THEME_ID=42`
   - "all routes" / "all pages" / "full route sweep" → `SCREENSHOTS_PATHS=all`
   - A comma-separated list of paths → `SCREENSHOTS_PATHS=…`
   - A directory path (e.g. "save to /tmp/foo") → `SCREENSHOTS_DIR=…`
   - "compare with baseline from /path" / "compare against main" → `SCREENSHOTS_BASELINE_DIR=…`; if the user names the baseline (e.g. "main") also set `SCREENSHOTS_BASELINE_LABEL=…`
3. Always include `LOAD_PLUGINS=1` so chat routes work.
4. If the user requests an unknown built-in theme name, tell them only `foundation` and `horizon` are supported — for any other theme use `SCREENSHOTS_THEME_URL`.
5. Always prefix with `TAKE_SCREENSHOTS=1`.
6. Run via `bin/rspec spec/system/theme_screenshots_spec.rb` from the repo root.
7. After the run, list the files saved (`ls` on the output dir) and surface paths to the user. Show failures if `bin/rspec` exits non-zero.

## Extending

To add more built-in themes, edit the `ALL_THEMES` constant at the top of the spec: `{ name: "label", id: <theme_id> }`.

To add more routes to the `all` sweep, edit the `ALL_SCREENSHOT_ROUTES` constant.
