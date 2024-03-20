import { getOwner } from "@ember/application";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import {
  PLUGIN_CONFIG_NAV_MODE_SIDEBAR,
  registerAdminPluginConfigNav,
} from "discourse/lib/admin-plugin-config-nav";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminPlugin from "admin/models/admin-plugin";

module("Integration | Component | admin-plugin-config-area", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders the plugin config nav and content", async function (assert) {
    registerAdminPluginConfigNav(
      "discourse-test-plugin",
      PLUGIN_CONFIG_NAV_MODE_SIDEBAR,
      [
        {
          route: "adminPlugins.show.discourse-test-plugin.one",
          label: "admin.title",
        },
        {
          route: "adminPlugins.show.discourse-test-plugin.two",
          label: "admin.back_to_forum",
        },
      ]
    );
    getOwner(this).lookup(
      "service:admin-plugin-config-nav-manager"
    ).currentPlugin = new AdminPlugin({ id: "discourse-test-plugin" });

    await render(hbs`
      <AdminPluginConfigArea>
        Test content
      </AdminPluginConfigArea>
    `);

    assert.strictEqual(
      document.querySelectorAll(".admin-plugin-inner-sidebar-nav__item").length,
      2,
      "it renders the correct number of nav items"
    );

    assert.strictEqual(
      document.querySelector(".admin-plugin-config-area").textContent.trim(),
      "Test content",
      "it renders the yielded content"
    );
  });
});
