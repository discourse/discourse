import { click, visit } from "@ember/test-helpers";
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
        ],
      })
    );

    server.put("/admin/site_settings/testplugin_enabled", () =>
      helper.response(200, {})
    );
  });

  test("shows plugin list and can toggle state", async function (assert) {
    await visit("/admin/plugins");

    assert
      .dom(
        "table.admin-plugins-list .admin-plugins-list__row .admin-plugins-list__name-details .admin-plugins-list__name-with-badges .admin-plugins-list__name"
      )
      .hasText("Some Test Plugin", "displays the plugin in the table");

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
});
