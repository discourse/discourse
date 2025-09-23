import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin - Plugins", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/plugins", () =>
      helper.response({
        plugins: [
          {
            id: "some-test-plugin",
            name: "some-test-plugin",
            humanized_name: "Some test plugin",
            about: "Plugin description",
            version: "0.1",
            url: "https://example.com",
            admin_route: {
              location: "testlocation",
              label: "test.plugin.label",
              full_location: "adminPlugins.testlocation",
            },
            enabled: true,
            enabled_setting: "testplugin_enabled",
            has_settings: true,
            is_official: true,
            commit_hash: "1234567890abcdef",
            commit_url:
              "https://github.com/username/some-test-plugin/commit/1234567890abcdef",
          },
          {
            id: "navigation-test-plugin",
            name: "navigation-test-plugin",
            humanized_name: "Navigation Test Plugin",
            about: "Plugin for testing navigation behavior",
            version: "0.2",
            url: "https://example.com",
            admin_route: {
              location: "navigation-test",
              label: "navigation.test.label",
              use_new_show_route: false,
            },
            enabled: false,
            enabled_setting: "navigation_test_plugin_enabled",
            has_settings: true,
          },
          {
            id: "new-route-plugin",
            name: "new-route-plugin",
            humanized_name: "New Route Plugin",
            about: "Plugin for testing new route navigation",
            version: "0.3",
            url: "https://example.com",
            admin_route: {
              location: "new-route-test",
              label: "new.route.test.label",
              use_new_show_route: true,
            },
            enabled: false,
            enabled_setting: "new_route_plugin_enabled",
            has_settings: true,
          },
        ],
      })
    );

    server.put("/admin/site_settings/testplugin_enabled", () =>
      helper.response(200, {})
    );

    server.put("/admin/site_settings/navigation_test_plugin_enabled", () =>
      helper.response(200, {})
    );

    server.put("/admin/site_settings/new_route_plugin_enabled", () =>
      helper.response(200, {})
    );

    server.get("/admin/plugins/new-route-plugin", () =>
      helper.response({ plugin: {} })
    );

    server.get("/admin/config/site_settings.json", () =>
      helper.response({ site_settings: [] })
    );
  });

  test("shows plugin list and can toggle state", async function (assert) {
    await visit("/admin/plugins");

    assert
      .dom(
        "table.admin-plugins-list .admin-plugins-list__row .admin-plugins-list__name-details .admin-plugins-list__name-with-badges .admin-plugins-list__name"
      )
      .hasText("Some test plugin", "displays the plugin in the table");

    assert
      .dom(".admin-plugins .admin-config-page .alert-error")
      .exists("shows an error for unknown routes");

    assert
      .dom(
        "table.admin-plugins-list tr .admin-plugins-list__version a.commit-hash"
      )
      .hasAttribute(
        "href",
        "https://github.com/username/some-test-plugin/commit/1234567890abcdef",
        "displays a commit hash with a link to commit url"
      );

    const toggleSelector =
      "table.admin-plugins-list tr .admin-plugins-list__enabled button";

    assert
      .dom(toggleSelector)
      .hasAria("checked", "true", "displays the plugin as enabled");

    await click(toggleSelector);

    assert
      .dom(toggleSelector)
      .hasAria("checked", "false", "displays the plugin as enabled");
  });

  test("navigates to site settings page when enabling plugin that does not use new show route", async function (assert) {
    await visit("/admin/plugins");

    const toggleSelector =
      "table.admin-plugins-list tr[data-plugin-name='navigation-test-plugin'] .admin-plugins-list__enabled button";

    assert
      .dom(toggleSelector)
      .hasAria("checked", "false", "plugin starts disabled");

    await click(toggleSelector);

    assert.strictEqual(
      currentURL(),
      "/admin/site_settings/category/all_results?filter=plugin%3Anavigation-test-plugin",
      "navigates to plugin settings with filter"
    );
  });

  test("navigates to plugin's settings page when enabling plugin that uses new show route", async function (assert) {
    await visit("/admin/plugins");

    const toggleSelector =
      "table.admin-plugins-list tr[data-plugin-name='new-route-plugin'] .admin-plugins-list__enabled button";

    assert
      .dom(toggleSelector)
      .hasAria("checked", "false", "plugin starts disabled");

    await click(toggleSelector);

    assert.strictEqual(
      currentURL(),
      "/admin/plugins/new-route-plugin/settings",
      "navigates to new plugin show route when use_new_show_route is true"
    );
  });
});
