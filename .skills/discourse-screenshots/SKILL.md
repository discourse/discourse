---
name: discourse-screenshots
description: Capture screenshots of the local Discourse site across the two core themes (Foundation, Horizon) and color modes (light, dark). Use when the user asks for "screenshots of themes", "light/dark mode shots", or similar.
---

# Discourse screenshots

Drives a system spec (`spec/system/theme_screenshots_spec.rb`) that discovers all system specs containing `screenshot_marker` marker calls, runs them under each combination of theme × device × color mode, and outputs PNGs plus a single `compare.html` viewer.

## How it works

Spec authors place `screenshot_marker(label: "my-label")` at the moment they want to capture. The orchestrator auto-discovers those specs and runs only the `it` blocks that contain a marker, skipping everything else. The `only:` kwarg restricts a capture to one device leg:

```ruby
screenshot_marker(label: "search-menu", only: :desktop)
```

Output files: `tmp/theme-screenshots/raw/{device}-{theme}-{mode}-{label}.png`
Comparison viewer: `tmp/theme-screenshots/compare.html` (tabs for device and color mode)

## Matrix (default)

| Theme      | Modes       | Devices         |
|------------|-------------|-----------------|
| Foundation | light, dark | desktop, mobile |
| Horizon    | light, dark | desktop, mobile |

## How to run

```bash
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 bin/rspec spec/system/theme_screenshots_spec.rb
```

`LOAD_PLUGINS=1` is always included so chat routes work.

### Arguments (env vars)

| Var                     | Default             | Purpose                                                       |
|-------------------------|---------------------|---------------------------------------------------------------|
| `TAKE_SCREENSHOTS`      | *(required)*        | Must be `1` for the spec to run.                             |
| `LOAD_PLUGINS`          | `1`                 | Always set so chat and plugin routes work.                    |
| `SCREENSHOTS_DIR`       | `tmp/theme-screenshots` | Where PNGs and the HTML viewer are written.              |
| `SCREENSHOTS_MODES`     | `light,dark`        | Comma-separated color modes.                                  |
| `SCREENSHOTS_DEVICES`   | `desktop,mobile`    | Comma-separated devices. Mobile uses Playwright WebKit.       |
| `SCREENSHOTS_THEMES`    | `foundation,horizon`| Comma-separated built-in theme names to include.              |
| `SCREENSHOTS_THEME_URL` | *(unset)*           | Git URL of a remote theme to install and add to the matrix.   |
| `SCREENSHOTS_THEME_NAME`| repo name           | Filename label for the remote/extra theme.                    |
| `SCREENSHOTS_SUBSET`    | *(unset)*           | Substring filter on marker labels — only captures markers whose label contains this string. |

### Examples

```bash
# Default — all themes × light/dark × desktop/mobile
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 bin/rspec spec/system/theme_screenshots_spec.rb

# Desktop, light mode only
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 SCREENSHOTS_DEVICES=desktop SCREENSHOTS_MODES=light \
  bin/rspec spec/system/theme_screenshots_spec.rb

# Foundation only, dark only
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 SCREENSHOTS_THEMES=foundation SCREENSHOTS_MODES=dark \
  bin/rspec spec/system/theme_screenshots_spec.rb

# Add a remote theme alongside the built-ins
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 \
  SCREENSHOTS_THEME_URL=https://github.com/org/my-theme \
  SCREENSHOTS_THEME_NAME=my-theme \
  bin/rspec spec/system/theme_screenshots_spec.rb

# Only capture markers whose label contains "topic"
TAKE_SCREENSHOTS=1 LOAD_PLUGINS=1 SCREENSHOTS_SUBSET=topic \
  bin/rspec spec/system/theme_screenshots_spec.rb
```

## Invocation instructions

When this skill is invoked:

1. Build the command from `$ARGUMENTS`. If no arguments are given, use the default matrix.
2. Parse free-form args into env vars (composable — handle multiple at once):
   - "dark only" / "light only" → `SCREENSHOTS_MODES=…`
   - "desktop only" / "mobile only" → `SCREENSHOTS_DEVICES=…`
   - "foundation only" / "just horizon" → `SCREENSHOTS_THEMES=…`
   - A git URL for a theme → `SCREENSHOTS_THEME_URL=…`; also set `SCREENSHOTS_THEME_NAME=<label>` if the user provides a name
   - A label substring (e.g. "only topic markers", "just signup") → `SCREENSHOTS_SUBSET=…`
   - A directory path (e.g. "save to /tmp/foo") → `SCREENSHOTS_DIR=…`
3. Always include `LOAD_PLUGINS=1`.
4. Always prefix with `TAKE_SCREENSHOTS=1`.
5. If the user requests an unknown built-in theme name, tell them only `foundation` and `horizon` are supported — for any other theme use `SCREENSHOTS_THEME_URL`.
6. Run via `bin/rspec spec/system/theme_screenshots_spec.rb` from the repo root.
7. After the run, list the files saved (`ls` on the raw dir) and surface the `compare.html` path to the user. Show failures if `bin/rspec` exits non-zero.

## Adding markers to a spec

In any system spec, `include ThemeScreenshotMarker` and call `screenshot_marker` at the point you want to capture:

```ruby
describe "Search" do
  include ThemeScreenshotMarker

  it "shows search results" do
    visit "/search"
    search_page.type_in_search("test")
    search_page.click_search_button

    screenshot_marker(label: "search-results")               # captured on all devices
    screenshot_marker(label: "search-menu", only: :desktop)  # desktop only
  end
end
```

The `include ThemeScreenshotMarker` line is required — without it, `screenshot_marker` is undefined when the spec is run directly. The orchestrator also auto-includes it as a safety net, but relying on that alone will break direct spec runs.
