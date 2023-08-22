import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

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
      helper.response()
    );
  });

  test("shows plugin list and can toggle state", async function (assert) {
    await visit("/admin/plugins");

    assert
      .dom("table.admin-plugins tr .plugin-name .name")
      .hasText("some-test-plugin", "displays the plugin in the table");

    assert
      .dom(".admin-plugins .admin-container .alert-error")
      .exists("shows an error for unknown routes");

    assert
      .dom("table.admin-plugins tr .version a.commit-hash")
      .hasAttribute(
        "href",
        "https://github.com/username/some-test-plugin/commit/1234567890abcdef",
        "displays a commit hash with a link to commit url"
      );

    const toggleSelector = "table.admin-plugins tr .col-enabled button";
    assert
      .dom(toggleSelector)
      .hasAttribute("aria-checked", "true", "displays the plugin as enabled");

    await click(toggleSelector);
    assert
      .dom(toggleSelector)
      .hasAttribute("aria-checked", "false", "displays the plugin as enabled");
  });
});
