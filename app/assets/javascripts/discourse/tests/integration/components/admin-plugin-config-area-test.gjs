import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { registerAdminPluginConfigNav } from "discourse/lib/admin-plugin-config-nav";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminPluginConfigArea from "admin/components/admin-plugin-config-area";
import AdminPlugin from "admin/models/admin-plugin";

module("Integration | Component | admin-plugin-config-area", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders the nav items along the top", async function (assert) {
    registerAdminPluginConfigNav("discourse-test-plugin", [
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

    await render(
      <template>
        <AdminPluginConfigArea>
          Test content
        </AdminPluginConfigArea>
      </template>
    );

    assert
      .dom(".admin-plugin-inner-sidebar-nav__item")
      .doesNotExist("renders the correct number of sidebar nav items");

    assert
      .dom(".admin-plugin-config-area")
      .hasText("Test content", "renders the yielded content");
  });
});
