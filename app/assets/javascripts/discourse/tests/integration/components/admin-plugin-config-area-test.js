import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import {
  PLUGIN_NAV_MODE_SIDEBAR,
  PLUGIN_NAV_MODE_TOP,
  registerAdminPluginConfigNav,
} from "discourse/lib/admin-plugin-config-nav";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminPlugin from "admin/models/admin-plugin";

module("Integration | Component | admin-plugin-config-area", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders the plugin config nav and content in the sidebar mode but not along the top", async function (assert) {
    registerAdminPluginConfigNav(
      "discourse-test-plugin",
      PLUGIN_NAV_MODE_SIDEBAR,
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
    getOwner(this).lookup("service:admin-plugin-nav-manager").currentPlugin =
      new AdminPlugin({ id: "discourse-test-plugin" });

    await render(hbs`
      <AdminPluginConfigArea>
        Test content
      </AdminPluginConfigArea>
    `);

    assert
      .dom(".admin-plugin-inner-sidebar-nav__item")
      .exists(
        { count: 3 },
        "renders the correct number of sidebar nav items (including always adding a Settings link)"
      );

    assert
      .dom(".admin-plugin-config-area")
      .hasText("Test content", "renders the yielded content");
  });

  test("it does not render the nav items in the sidebar when using top mode but it does along the top", async function (assert) {
    registerAdminPluginConfigNav("discourse-test-plugin", PLUGIN_NAV_MODE_TOP, [
      {
        route: "adminPlugins.show.discourse-test-plugin.one",
        label: "admin.title",
      },
      {
        route: "adminPlugins.show.discourse-test-plugin.two",
        label: "admin.back_to_forum",
      },
    ]);
    getOwner(this).lookup("service:admin-plugin-nav-manager").currentPlugin =
      new AdminPlugin({ id: "discourse-test-plugin" });

    await render(hbs`
      <AdminPluginConfigArea>
        Test content
      </AdminPluginConfigArea>
    `);

    assert
      .dom(".admin-plugin-inner-sidebar-nav__item")
      .doesNotExist("renders the correct number of sidebar nav items");

    assert
      .dom(".admin-plugin-config-area")
      .hasText("Test content", "renders the yielded content");
  });
});
