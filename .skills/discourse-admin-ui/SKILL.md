---
name: discourse-admin-ui
description: Use when creating, modifying, or reviewing Discourse admin interfaces in core or plugins. Covers admin sidebar navigation, config pages, route/templates, DPageHeader breadcrumbs/tabs/actions, DPageSubheader, AdminConfigAreaCard, help insets, d-table responsive tables, empty states, third-level new/edit routes, filtered site setting pages, plugin admin UIs, translations, accessibility, and current in-repo examples.
---

# Discourse Admin UI

Use this skill before building or reviewing any Discourse admin UI. It distills the Meta guide
[Creating consistent admin interfaces](https://meta.discourse.org/t/creating-consistent-admin-interfaces/326780?tl=en)
and points to current code examples so agents do not need to rediscover the conventions.

## Workflow

1. Classify the admin surface before editing:
   - Core config page or general admin route: read [references/page-shell.md](references/page-shell.md).
   - Cards, forms, help content, tables, empty lists, or third-level new/edit pages: read [references/content-patterns.md](references/content-patterns.md).
   - A page that mainly exposes site settings by `area` or `category`: read [references/filtered-settings-pages.md](references/filtered-settings-pages.md).
   - Plugin admin UI under `/admin/plugins/:plugin`: read [references/plugin-admin-interfaces.md](references/plugin-admin-interfaces.md).
2. Inspect nearby examples in the same admin section or plugin before designing new structure. Prefer an existing route/component split over inventing a parallel pattern.
3. Keep admin copy translatable and sentence-cased. Config page title and description keys normally live under `admin.config.page_name.title` and `admin.config.page_name.header_description`.
4. Use standard UI primitives:
   - `DPageHeader` for the page shell, breadcrumbs, top actions, and tabs.
   - `DPageSubheader` for section-level headings and section actions.
   - `AdminConfigAreaCard` for grouped configuration content.
   - FormKit for forms.
   - `d-table` classes for responsive tables.
   - `AdminConfigAreaEmptyList` for createable empty lists.
5. For templates or styles, also follow `.skills/discourse-writing-html-css`. For QUnit tests, use `.skills/discourse-writing-js-tests`.
6. Verify route reloads work for nested/new/edit admin routes, especially plugin routes and third-level pages.
7. Always run `bin/lint --fix` on changed files.

## Quick Decisions

- Adding a sidebar-visible admin config page? Add the route, template, translations, and an `ADMIN_NAV_MAP` entry with `name`, `route`, `label`, `description`, and `icon`.
- Adding a settings-only config page? Use `AdminConfigWithSettingsRoute`, `AdminAreaSettingsBaseController`, and `AdminAreaSettings`.
- Adding a related list of records? Use a standalone index table plus separate `new` and `edit` routes rather than inline row forms.
- Adding a plugin configuration UI? Use `add_admin_route(..., use_new_show_route: true)`, plugin routes under `admin.adminPlugins.show`, and `api.addAdminPluginConfigurationNav`.
- Adding page actions? Put primary/secondary actions in `DPageHeader` or `DPageSubheader` yielded actions; use specific labels such as "Add webhook", not generic labels such as "Add".

## Local Anchors

- Core admin nav map: `frontend/discourse/app/lib/sidebar/admin-nav-map.js`
- Core admin route map: `frontend/discourse/admin/routes/admin-route-map.js`
- Page header component: `frontend/discourse/app/ui-kit/d-page-header.gjs`
- Page subheader component: `frontend/discourse/app/ui-kit/d-page-subheader.gjs`
- Filtered settings example: `frontend/discourse/admin/templates/admin-config/localization/settings.gjs`
- Header with tabs/actions example: `frontend/discourse/admin/templates/admin/backups.gjs`
- Custom config page example: `frontend/discourse/admin/templates/admin-config/about.gjs`
- Table and empty list example: `frontend/discourse/admin/templates/admin-permalinks/index.gjs`
- Plugin nav example: `plugins/discourse-ai/assets/javascripts/discourse/initializers/admin-plugin-configuration-nav.js`
- Plugin route map example: `plugins/discourse-ai/assets/javascripts/discourse/admin-discourse-ai-plugin-route-map.js`
