---
name: discourse-theme-screenshots
description: Capture screenshots of the local Discourse site across the two core themes (Foundation, Horizon) and color modes (light, dark). Use when the user asks for "screenshots of themes", "light/dark mode shots", or similar.
---

# Discourse theme screenshots

Drives a system spec (`spec/system/theme_screenshots_spec.rb`) that boots a headless Playwright browser, cycles through the two core themes × color-mode matrix, and drops PNGs into `tmp/theme-screenshots/`.

## Matrix (hardcoded)

| Theme      | Theme ID | Modes       |
|------------|----------|-------------|
| Foundation | `-1`     | light, dark |
| Horizon    | `-2`     | light, dark |

Output is eight files by default — one per theme × mode × device: `foundation-light-desktop.png`, `foundation-light-mobile.png`, `foundation-dark-desktop.png`, `foundation-dark-mobile.png`, plus the matching four `horizon-*` files. When signed in, the role (`-user` / `-admin`) is appended (e.g. `horizon-dark-mobile-admin.png`).

Theme selection isn't configurable — this skill is deliberately scoped to the two core system themes. For a different theme, edit the `THEMES` array at the top of the spec.

## How it works

- Applies each theme per-request via `?preview_theme_id=<id>` on the visited URL.
- Uses the core theme IDs directly: Foundation is `-1`, Horizon is `-2` (from `Theme::CORE_THEMES`).
- Toggles dark mode by calling Playwright's `emulate_media(colorScheme: "dark")` — Discourse serves the right stylesheet based on `prefers-color-scheme` so no account/preference shenanigans needed.
- Fabricates a handful of realistic-sounding topics so the homepage isn't empty.
- Uses Playwright's native `fullPage: true` screenshot for tall captures.

The spec is **skipped by default** — it only runs when `TAKE_SCREENSHOTS=1` is set, so it won't slow down regular CI / `bin/rspec` runs.

## How to run

Default matrix, default output directory:

```bash
TAKE_SCREENSHOTS=1 bin/rspec spec/system/theme_screenshots_spec.rb
```

Screenshots land in `tmp/theme-screenshots/`.

### Arguments (env vars)

| Var                  | Default                      | Purpose                                                    |
|----------------------|------------------------------|------------------------------------------------------------|
| `TAKE_SCREENSHOTS`   | *(unset — spec is skipped)*  | Must be `1` for the spec to run.                           |
| `SCREENSHOTS_DIR`    | `tmp/theme-screenshots`      | Where PNGs are written.                                    |
| `SCREENSHOTS_PATH`   | `/`                          | Path on the site to capture (e.g. `/latest`, `/categories`, `/c/general`). Also accepts the sentinel `/t/random`, which the spec expands to a randomly-picked fabricated topic's URL. `preview_theme_id` is appended as a query param. |
| `SCREENSHOTS_MODES`  | `light,dark`                 | Comma-separated color modes (`light`, `dark`).             |
| `SCREENSHOTS_AS`     | `anonymous`                  | Who to sign in as: `anonymous`, `user`, or `admin`. Non-anonymous values append `-admin` / `-user` to filenames. |
| `SCREENSHOTS_DEVICES` | `desktop,mobile`            | Comma-separated devices. Mobile uses Playwright's WebKit driver with an iPhone UA so Discourse's server-side mobile detection serves the mobile HTML. |

### Examples

Default run:

```bash
TAKE_SCREENSHOTS=1 bin/rspec spec/system/theme_screenshots_spec.rb
```

Captured on `/categories`:

```bash
TAKE_SCREENSHOTS=1 \
  SCREENSHOTS_PATH=/categories \
  bin/rspec spec/system/theme_screenshots_spec.rb
```

PNGs going to a custom folder:

```bash
TAKE_SCREENSHOTS=1 \
  SCREENSHOTS_DIR=/tmp/my-shots \
  bin/rspec spec/system/theme_screenshots_spec.rb
```

Signed in as admin (captures admin-only UI bits like the admin menu):

```bash
TAKE_SCREENSHOTS=1 SCREENSHOTS_AS=admin bin/rspec spec/system/theme_screenshots_spec.rb
```

Dark mode only:

```bash
TAKE_SCREENSHOTS=1 SCREENSHOTS_MODES=dark bin/rspec spec/system/theme_screenshots_spec.rb
```

A specific page as admin (e.g. "on /categories as admin, take a screenshot"):

```bash
TAKE_SCREENSHOTS=1 SCREENSHOTS_AS=admin SCREENSHOTS_PATH=/categories bin/rspec spec/system/theme_screenshots_spec.rb
```

A random fabricated topic as a regular user:

```bash
TAKE_SCREENSHOTS=1 SCREENSHOTS_AS=user SCREENSHOTS_PATH=/t/random bin/rspec spec/system/theme_screenshots_spec.rb
```

Desktop only (skip the mobile pass — faster):

```bash
TAKE_SCREENSHOTS=1 SCREENSHOTS_DEVICES=desktop bin/rspec spec/system/theme_screenshots_spec.rb
```

Mobile only:

```bash
TAKE_SCREENSHOTS=1 SCREENSHOTS_DEVICES=mobile bin/rspec spec/system/theme_screenshots_spec.rb
```

## Invocation instructions for the assistant

When this skill is invoked:

1. Build the command from `$ARGUMENTS`. If no arguments are given, use the default matrix.
2. Parse free-form args into env vars. Arguments are composable — handle multiple in one request (e.g. "on /categories as admin" → both `SCREENSHOTS_PATH=/categories` AND `SCREENSHOTS_AS=admin`):
   - "dark only" / "light only" → `SCREENSHOTS_MODES=…`
   - Any site-relative path — `on /X`, `at /X`, `/X page`, or a bare path like `/categories`, `/latest`, `/c/general`, `/t/some-topic/123` → `SCREENSHOTS_PATH=…`. Keep the exact path including any query string; the spec appends `preview_theme_id` correctly whether or not one already exists.
   - "a random topic" / "random topic route" → `SCREENSHOTS_PATH=/t/random` (spec expands at runtime).
   - "as admin" / "signed in as admin" / "logged in as admin" → `SCREENSHOTS_AS=admin`
   - "as user" / "as a regular user" → `SCREENSHOTS_AS=user`
   - "desktop only" / "just desktop" → `SCREENSHOTS_DEVICES=desktop`. "mobile only" / "just mobile" → `SCREENSHOTS_DEVICES=mobile`. If unspecified, the default (`desktop,mobile`) captures both.
   - A directory path (when clearly an output location, e.g. "save to /tmp/foo") → `SCREENSHOTS_DIR=…`
3. Theme selection is NOT configurable via env — don't try to filter to a single theme. If the user asks for just one theme, tell them the spec hardcodes Foundation + Horizon, and point them at the `THEMES` array at the top of `spec/system/theme_screenshots_spec.rb`.
4. Always prefix with `TAKE_SCREENSHOTS=1`.
5. Run via `bin/rspec spec/system/theme_screenshots_spec.rb` from the repo root. The spec prints each saved filepath with a camera emoji.
6. After the run, list the files actually saved (via `ls` on the output dir) and surface those paths to the user. Don't claim success if `bin/rspec` exited non-zero — show the failure instead.

## Extending

- To screenshot different themes, edit the `THEMES` constant at the top of the spec. Format: `{ name: "label", id: <theme_id> }`.
- To add color modes beyond light/dark: `emulate_media` also accepts `"no-preference"`. Add it to the `SCREENSHOTS_MODES` input and the spec will pass it straight through.
