# Filtered Settings Pages

Use this reference when adding an admin config page that mainly displays a curated list of site settings by `area` or `category`.

## When to use

Use a filtered settings page when the admin task is best represented as related site settings and does not yet need a specialized custom workflow. If the page needs custom records, complex validation, setup steps, or rich help content, build a custom config page using the patterns in [content-patterns.md](content-patterns.md).

## Site setting grouping

Settings can be displayed by:

- `area`: preferred when settings from multiple categories belong to a user-facing admin task.
- `category`: useful when the page maps to a top-level site settings category.

Add the matching `settings_area` or `settings_category` to the page's `ADMIN_NAV_MAP` entry.

## Files to add

For a route like `/admin/config/localization`, inspect the current implementation:

- Route: `frontend/discourse/admin/routes/admin-config/localization.js`
- Settings controller: `frontend/discourse/admin/controllers/admin-config/localization/settings.js`
- Template: `frontend/discourse/admin/templates/admin-config/localization/settings.gjs`
- Nav entry: `frontend/discourse/app/lib/sidebar/admin-nav-map.js`

## Route map

Add the route under `adminConfig` in `frontend/discourse/admin/routes/admin-route-map.js`. Settings pages usually make the `settings` child route the index path:

```js
this.route("example", { path: "/example" }, function () {
  this.route("settings", { path: "/" });
});
```

Use hyphenated URL slugs. Route names stay camelCase where Ember expects that.

## Route class

The page route should extend `AdminConfigWithSettingsRoute` and provide a title token:

```js
import { i18n } from "discourse-i18n";
import AdminConfigWithSettingsRoute from "../admin-config-with-settings-route";

export default class AdminConfigExampleRoute extends AdminConfigWithSettingsRoute {
  titleToken() {
    return i18n("admin.config.example.title");
  }
}
```

## Settings controller

The settings child controller should extend `AdminAreaSettingsBaseController` so search and filtering work consistently:

```js
import AdminAreaSettingsBaseController from "discourse/admin/controllers/admin-area-settings-base";

export default class AdminConfigExampleSettingsController extends AdminAreaSettingsBaseController {}
```

## Template

Use `DPageHeader` and `AdminAreaSettings`. Hide internal breadcrumbs inside `AdminAreaSettings` because the page header owns breadcrumbs.

```gjs
import AdminAreaSettings from "discourse/admin/components/admin-area-settings";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @hideTabs={{true}}
    @titleLabel={{i18n "admin.config.example.title"}}
    @descriptionLabel={{i18n "admin.config.example.header_description"}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/config/example"
        @label={{i18n "admin.config.example.title"}}
      />
    </:breadcrumbs>
  </DPageHeader>

  <div class="admin-config-page__main-area">
    <AdminAreaSettings
      @showBreadcrumb={{false}}
      @area="example"
      @path="/admin/config/example"
      @filter={{@controller.filter}}
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    />
  </div>
</template>
```

Use `@categories={{...}}` instead of `@area` only when category filtering is the intended behavior.

## Checklist

- Add title, header description, and optional keywords translations.
- Add `ADMIN_NAV_MAP` entry with `settings_area` or `settings_category`.
- Add route, controller, template, and route map entry.
- Confirm `/admin/config/example` reloads directly.
- Run `bin/lint --fix` on changed files.
