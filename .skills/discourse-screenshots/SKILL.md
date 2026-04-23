---
name: discourse-screenshots
description: Capture screenshots of the local Discourse site across the two core themes (Foundation, Horizon) and color modes (light, dark). Use when the user asks for "screenshots of themes", "light/dark mode shots", or similar.
---

# Discourse screenshots

Drives a system spec (`spec/system/theme_screenshots_spec.rb`) that boots a headless Playwright browser, cycles through the two core themes × color-mode matrix, and drops PNGs into `tmp/theme-screenshots/`.

## Matrix (hardcoded)

| Theme      | Theme ID | Modes       |
|------------|----------|-------------|
| Foundation | `-1`     | light, dark |
| Horizon    | `-2`     | light, dark |

Output is eight files by default — one per theme × mode × device: `foundation-light-desktop.png`, `foundation-light-mobile.png`, `foundation-dark-desktop.png`, `foundation-dark-mobile.png`, plus the matching four `horizon-*` files. When signed in, the role (`-user` / `-admin`) is appended (e.g. `horizon-dark-mobile-admin.png`).

## How to run

```bash
TAKE_SCREENSHOTS=1 bin/rspec spec/system/theme_screenshots_spec.rb
```

Screenshots land in `tmp/theme-screenshots/`.

### Arguments (env vars)

| Var                   | Default                      | Purpose                                                    |
|-----------------------|------------------------------|------------------------------------------------------------|
| `TAKE_SCREENSHOTS`    | *(unset — spec is skipped)*  | Must be `1` for the spec to run.                           |
| `SCREENSHOTS_DIR`     | `tmp/theme-screenshots`      | Where PNGs are written.                                    |
| `SCREENSHOTS_PATH`    | `/`                          | Path on the site to capture (e.g. `/latest`, `/categories`, `/c/general`). Also accepts `/t/random`, which the spec expands to a randomly-picked fabricated topic. |
| `SCREENSHOTS_MODES`   | `light,dark`                 | Comma-separated color modes (`light`, `dark`).             |
| `SCREENSHOTS_AS`      | `anonymous`                  | Who to sign in as: `anonymous`, `user`, or `admin`.        |
| `SCREENSHOTS_DEVICES` | `desktop,mobile`             | Comma-separated devices. Mobile uses Playwright's WebKit driver with an iPhone UA. |
| `SCREENSHOTS_THEMES`  | `foundation,horizon`         | Comma-separated theme names to capture. Use `foundation` or `horizon` to restrict to one. |

### Examples

```bash
# /categories page as admin, dark only, desktop only
TAKE_SCREENSHOTS=1 SCREENSHOTS_PATH=/categories SCREENSHOTS_AS=admin \
  SCREENSHOTS_MODES=dark SCREENSHOTS_DEVICES=desktop \
  bin/rspec spec/system/theme_screenshots_spec.rb

# Random fabricated topic as a regular user
TAKE_SCREENSHOTS=1 SCREENSHOTS_AS=user SCREENSHOTS_PATH=/t/random \
  bin/rspec spec/system/theme_screenshots_spec.rb
```

## Invocation instructions

When this skill is invoked:

1. Build the command from `$ARGUMENTS`. If no arguments are given, use the default matrix.
2. Parse free-form args into env vars (composable — handle multiple at once):
   - "dark only" / "light only" → `SCREENSHOTS_MODES=…`
   - Any site-relative path — `on /X`, `at /X`, `/X page`, or a bare path → `SCREENSHOTS_PATH=…`
   - "a random topic" → `SCREENSHOTS_PATH=/t/random`
   - "as admin" / "as user" → `SCREENSHOTS_AS=…`
   - "desktop only" / "mobile only" → `SCREENSHOTS_DEVICES=…`
   - "foundation only" / "just horizon" / any theme name → `SCREENSHOTS_THEMES=…` (comma-separated; values are `foundation` and/or `horizon`)
   - A directory path (e.g. "save to /tmp/foo") → `SCREENSHOTS_DIR=…`
3. If the user requests an unknown theme name, tell them only `foundation` and `horizon` are supported.
4. Always prefix with `TAKE_SCREENSHOTS=1`.
5. Run via `bin/rspec spec/system/theme_screenshots_spec.rb` from the repo root.
6. After the run, list the files saved (`ls` on the output dir) and surface paths to the user. Show failures if `bin/rspec` exits non-zero.

## Extending

To screenshot different themes, edit the `THEMES` constant at the top of the spec: `{ name: "label", id: <theme_id> }`.
