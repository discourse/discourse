import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminPluginConfigPage from "discourse/admin/components/admin-plugin-config-page";
import AdminPlugin from "discourse/admin/models/admin-plugin";
import { registerAdminPluginConfigNav } from "discourse/lib/admin-plugin-config-nav";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const PLUGIN_ID = "discourse-test-plugin";

module("Integration | Component | AdminPluginConfigPage", function (hooks) {
  setupRenderingTest(hooks);

  test("hides the tab nav when the plugin only has a settings tab", async function (assert) {
    const plugin = new AdminPlugin({
      id: PLUGIN_ID,
      name: PLUGIN_ID,
      humanized_name: "Test plugin",
    });
    getOwner(this).lookup("service:admin-plugin-nav-manager").currentPlugin =
      plugin;

    await render(
      <template>
        <AdminPluginConfigPage @plugin={{plugin}}>
          Test content
        </AdminPluginConfigPage>
      </template>
    );

    assert.dom(".d-nav-submenu").doesNotExist();
  });

  test("shows the tab nav when the plugin has more than one tab", async function (assert) {
    registerAdminPluginConfigNav(PLUGIN_ID, [
      {
        route: "adminPlugins.show.settings",
        label: "admin.plugins.change_settings_short",
      },
      {
        route: "adminPlugins.show.discourse-test-plugin.one",
        label: "admin.title",
      },
    ]);
    const plugin = new AdminPlugin({
      id: PLUGIN_ID,
      name: PLUGIN_ID,
      humanized_name: "Test plugin",
    });
    getOwner(this).lookup("service:admin-plugin-nav-manager").currentPlugin =
      plugin;

    await render(
      <template>
        <AdminPluginConfigPage @plugin={{plugin}}>
          Test content
        </AdminPluginConfigPage>
      </template>
    );

    assert.dom(".admin-plugin-config-page__top-nav-item").exists({ count: 2 });
  });
});
