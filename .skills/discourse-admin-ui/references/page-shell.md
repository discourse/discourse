# Page Shell, Navigation, and Routes

Use this reference when adding or changing a core admin page, page header, breadcrumbs, tabs, or sidebar entry.

## Admin page shape

Most admin config pages sit in this hierarchy:

```text
Admin interface
Config page in sidebar
Optional third-level tabs
New/edit/show routes for records
```

Every sidebar-visible config page needs a stable navigation entry, browser title, page title, and page description. This supports consistency now and admin search/navigation enhancements later.

## Sidebar entries

Add config pages to `ADMIN_NAV_MAP` in `frontend/discourse/app/lib/sidebar/admin-nav-map.js`.

Required or expected keys:

- `name`: unique `snake_case` identifier.
- `route`: Ember route name. Prefer this over `href`.
- `label`: I18n key, usually `admin.config.page_name.title`.
- `description`: I18n key, usually `admin.config.page_name.header_description`.
- `icon`: FontAwesome icon name used in the sidebar.

Use optional keys when relevant:

- `routeModels`: route params in route order.
- `moderator`: `true` if moderators can access the page.
- `keywords`: I18n key containing `|`-separated search synonyms.
- `links`: third-level child routes for admin search; these are not sidebar rows.
- `settings_area` or `settings_category`: for pages backed by filtered site settings.
- `multi_tabbed`: `true` when a page has settings plus other tabs.

Example to inspect: `frontend/discourse/app/lib/sidebar/admin-nav-map.js`, especially `admin_localization`, `admin_login`, and `admin_permalinks`.

## Translations

Core config page title and description keys should be shaped like this:

```yaml
en:
  js:
    admin:
      config:
        page_name:
          title: "Page title"
          header_description: "What admins can manage here."
          keywords: "optional|search|terms"
```

Keep UI text sentence-cased unless the string is a table header or a proper name. Do not split translated sentences around links or interpolated values; use placeholders.

## DPageHeader

Use `DPageHeader` from `discourse/ui-kit/d-page-header` for the top of admin pages.

Include:

- `@titleLabel`: translated page title.
- `@descriptionLabel`: translated page description.
- `@learnMoreUrl`: optional docs URL.
- `@hideTabs={{true}}`: when the page has no third-level tabs.
- `:breadcrumbs`: one `DBreadcrumbsItem` for `/admin`, plus the current page and any parent context.
- `:actions`: page-level actions. Use yielded `actions.Primary`, `actions.Default`, `actions.Danger`, or `actions.Wrapped`.
- `:tabs`: third-level `DNavItem` entries.

The component automatically hides itself on admin `new` and `edit` route segments. Override with `@shouldDisplay` only when the route intentionally needs a header.

Current examples:

- Simple page header: `frontend/discourse/admin/templates/admin-config/about.gjs`
- Header around filtered settings: `frontend/discourse/admin/templates/admin-config/localization/settings.gjs`
- Header with actions and tabs: `frontend/discourse/admin/templates/admin/backups.gjs`
- Plugin wrapper header: `frontend/discourse/admin/components/admin-plugin-config-page.gjs`

Minimal shape:

```gjs
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.example.title"}}
    @descriptionLabel={{i18n "admin.config.example.header_description"}}
    @hideTabs={{true}}
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
    {{outlet}}
  </div>
</template>
```

## Tabs

Use tabs only for related views inside the same admin context. Do not use them as primary admin navigation; the sidebar owns that.

Tabs are rendered in the `DPageHeader` `:tabs` block with `DNavItem` from `discourse/ui-kit/d-nav-item`.

```gjs
<:tabs>
  <DNavItem
    @route="admin.example.settings"
    @label="settings"
    class="admin-example-tabs__settings"
  />
  <DNavItem
    @route="admin.example.records"
    @label="admin.example.records"
    class="admin-example-tabs__records"
  />
</:tabs>
```

If plugins should extend the tab list, include the established `PluginOutlet` for that area rather than hardcoding plugin links.

## Browser titles

Admin routes should extend Discourse route classes and implement `titleToken()` when they own a browser title:

```js
import { i18n } from "discourse-i18n";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminExampleRoute extends DiscourseRoute {
  titleToken() {
    return i18n("admin.config.example.title");
  }
}
```

For filtered settings pages, use the specialized route class described in [filtered-settings-pages.md](filtered-settings-pages.md).

## Breadcrumbs

Breadcrumbs appear above the page header content on normal admin pages. Use a `/admin` crumb first, then page hierarchy crumbs, and mark the current page by using the current path and title. Do not add the normal header/breadcrumb area to third-level new/edit pages; use a back link there instead.

The implementation is via `DBreadcrumbsItem` yielded into the `DPageHeader`; `DPageHeader` provides the container.
