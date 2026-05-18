# Things to revisit

Open questions and deferred work for the visual editor plugin. Each
entry: what, why deferred, and what'd unblock it.

## Editor-only assets actually shipping only to staff

**What**: Today every byte of the plugin's CSS and JS ships to every
user on every page, even though only admins can use the editor. We split
`visual-editor.scss` into `visual-editor.scss` (block content) and
`admin/visual-editor-chrome.scss` (editor chrome) for *organization*,
but both files load universally. Same story for the editor-only JS in
`assets/javascripts/discourse/components/editor/`, `services/`,
`modifiers/`, etc.

**Why deferred**: Discourse's plugin asset pipeline doesn't expose a
per-asset staff gate.

- `register_asset` (`lib/plugin/instance.rb:783`) routes by `:mobile` /
  `:desktop` / `:color_definitions` only. There's no `:admin` or
  `:staff` flag, and the `stylesheets/admin/` path convention is purely
  organizational — `lib/discourse_plugin_registry.rb:188-211` does not
  switch on path.
- Plugin stylesheets are then injected via
  `Discourse.find_plugin_css_assets` (`lib/discourse.rb:432`) and
  `app/views/common/_discourse_stylesheet.html.erb` lines 21-37 — those
  filter by mobile/desktop only, not by user permission.
- The `:admin` bundle in core (`_discourse_stylesheet.html.erb:12-14`)
  IS gated by `if staff?`, but that's for core's own
  `app/assets/stylesheets/admin.scss`, not for plugin stylesheets.
- `register_asset_filter` exists (`lib/plugin/instance.rb:756`) but
  it filters the ENTIRE plugin's asset set — too coarse for our
  per-file need.
- For JS: `Plugin::JsManager.admin_js_asset_exists?`
  (`lib/plugin/js_manager.rb:13-16`) does auto-detect
  `admin/assets/javascripts/` and compile a separate `:admin` entry
  that's gated by `include_admin_asset: staff?` in
  `app/views/layouts/application.html.erb:28`. So the JS side has the
  mechanism — but it needs the file to physically live under
  `admin/assets/javascripts/`. CSS doesn't have the parallel
  convention.

**What'd unblock it**:

1. **Talk to the core team** about either:
   - Adding a `:admin` (or `:staff`) flag to `register_asset` for CSS
     that routes to a staff-gated bundle.
   - OR matching the JS-side convention: auto-detect files under
     `admin/assets/stylesheets/` and emit them only for staff via a
     parallel `discourse_stylesheet_link_tag(:plugin_admin, ...)` block.
2. **Alternative if core can't move**: ship the editor chrome CSS via
   JS-injected `<style>` element on `VisualEditorService.enter()`,
   removed on `exit()`. Plumbing is fine (precedent in
   `frontend/discourse/app/instance-initializers/current-user-mention-css.js`)
   but loses SCSS preprocessing — the chrome SCSS would need to live as
   a JS template literal or go through a build-time transform.

**Action**: check with the team whether core can grow a real per-asset
staff gate for plugin CSS. If yes, we adopt it. If no, plan B is the
runtime injection.

## Other items (add here as they come up)

_None yet._
