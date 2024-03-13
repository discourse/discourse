import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | admin-plugin-config-area", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders the plugin config nav and content", async function (assert) {
    this.set("innerSidebarNavLinks", [
      {
        route: "adminPlugins.show.discourse-test-plugin.one",
        label: "admin.title",
      },
      {
        route: "adminPlugins.show.discourse-test-plugin.two",
        label: "admin.back_to_forum",
      },
    ]);

    await render(hbs`
      <AdminPluginConfigArea @innerSidebarNavLinks={{this.innerSidebarNavLinks}}>
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
