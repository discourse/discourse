# Plugin Admin Interfaces

Use this reference when creating or reviewing a custom plugin admin UI under `/admin/plugins/:plugin`.

## When to build one

Build a plugin admin UI when a plugin needs more than a generated settings list: record management, setup workflows, reports, nested pages, custom tables, or multiple related configuration views. If the plugin only exposes site settings, rely on the generated settings page.

Core examples to inspect:

- Discourse AI: `plugins/discourse-ai`
- Data Explorer: `plugins/discourse-data-explorer`
- Chat Integration: `plugins/discourse-chat-integration`
- Gamification: `plugins/discourse-gamification`

## Server-side registration

Use `add_admin_route` in `plugin.rb` and pass `use_new_show_route: true` so the plugin uses the modern plugin show page:

```ruby
add_admin_route("plugin_example.title", "plugin-example", { use_new_show_route: true })
```

Some plugins pass the options hash as the third argument; others use keyword style. Follow nearby style.

Examples:

- `plugins/discourse-ai/plugin.rb`
- `plugins/discourse-data-explorer/plugin.rb`
- `plugins/discourse-chat-integration/plugin.rb`

## Route map

Plugin admin routes should attach to `admin.adminPlugins.show` with `path: "/plugins"`.

Create a route map such as `assets/javascripts/discourse/admin-plugin-example-plugin-route-map.js`:

```js
export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",

  map() {
    this.route("plugin-example-items", { path: "items" }, function () {
      this.route("new");
      this.route("edit", { path: "/:id/edit" });
    });
  },
};
```

Current examples:

- `plugins/discourse-ai/assets/javascripts/discourse/admin-discourse-ai-plugin-route-map.js`
- `plugins/discourse-data-explorer/assets/javascripts/discourse/explorer-route-map.js`
- `plugins/discourse-chat-integration/assets/javascripts/discourse/admin-chat-integration-plugin-route-map.js`

## File locations

Modern plugin admin route JS files live under:

```text
admin/assets/javascripts/discourse/routes/admin-plugins/show/
```

Templates live under:

```text
admin/assets/javascripts/discourse/templates/admin-plugins/show/
```

Simple routes usually have one template like:

```text
admin/assets/javascripts/discourse/templates/admin-plugins/show/plugin-example-items.gjs
```

Nested routes use the normal Ember structure with `index.gjs`, `new.gjs`, `edit.gjs`, or route-specific names under the route folder.

## Plugin navigation

Register plugin configuration navigation from an initializer, and only run it for admins:

```js
import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "plugin-example";

export default {
  name: "plugin-example-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "plugin_example.items.short_title",
          route: "adminPlugins.show.plugin-example-items",
          description: "plugin_example.items.description",
        },
      ]);
    });
  },
};
```

The plugin's generated settings link is added automatically. Do not duplicate it in `addAdminPluginConfigurationNav`.

Top tabs are preferred for plugin navigation. Avoid introducing an inner sidebar for new plugin UIs.

Example: `plugins/discourse-ai/assets/javascripts/discourse/initializers/admin-plugin-configuration-nav.js`.

## Page structure

The plugin show wrapper renders the main `DPageHeader`; plugin index routes should normally render `DPageSubheader` to describe the selected tab and provide tab-local actions.

Use the same content primitives as core admin pages:

- `AdminConfigAreaCard` for grouped forms and setup areas.
- `AdminConfigAreaEmptyList` for empty createable lists.
- `d-table` classes for growing record lists.
- Third-level `new` and `edit` routes for forms.
- `BackButton` on new/edit pages instead of the full header.

Examples:

- Plugin subheader and table: `plugins/discourse-data-explorer/admin/assets/javascripts/admin/templates/admin-plugins/show/explorer/index.gjs`
- Plugin nested detail page: `plugins/discourse-chat-integration/admin/assets/javascripts/discourse/templates/admin-plugins/show/discourse-chat-integration-providers/show.gjs`
- Plugin edit card: `plugins/discourse-ai/admin/assets/javascripts/discourse/templates/admin-plugins/show/discourse-ai-features/edit.gjs`

## Header actions outlet

If a plugin needs actions in the main plugin page header rather than inside a tab/subsection, render a component into the `admin-plugin-config-page-actions` outlet from the same initializer that registers plugin navigation.

```js
api.renderInOutlet(
  "admin-plugin-config-page-actions",
  PluginExampleAdminActions
);
```

The outlet receives the plugin model and `DPageHeader` action components through `outletArgs`; use those instead of hand-rolling header buttons.

Implementation anchor: `frontend/discourse/admin/components/admin-plugin-config-page.gjs`.

## Checklist

- Register the plugin admin route with `use_new_show_route: true`.
- Add a plugin route map under `admin.adminPlugins.show`.
- Add route JS and templates under `admin/assets/javascripts/discourse/...`.
- Register top-tab navigation with `api.addAdminPluginConfigurationNav` in an admin-only initializer.
- Use `DPageSubheader` inside plugin index routes.
- Use cards, tables, empty states, FormKit, and third-level routes consistently with core admin pages.
- Confirm direct reload works for every plugin route, including `new` and `edit`.
- Run `bin/lint --fix` on changed files.
