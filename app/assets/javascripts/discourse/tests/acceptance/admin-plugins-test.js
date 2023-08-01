import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
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
  });

  test("shows plugin list", async function (assert) {
    await visit("/admin/plugins");
    const table = query("table.admin-plugins");
    assert.strictEqual(
      table.querySelector("tr .plugin-name .name").innerText,
      "some-test-plugin",
      "displays the plugin in the table"
    );

    assert.true(
      exists(".admin-plugins .admin-container .alert-error"),
      "displays an error for unknown routes"
    );

    assert.strictEqual(
      table.querySelector("tr .version a.commit-hash").href,
      "https://github.com/username/some-test-plugin/commit/1234567890abcdef",
      "displays a commit hash with a link to commit url"
    );
  });
});
