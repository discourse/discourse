import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AdminPluginsListItem from "admin/components/admin-plugins-list-item";

module("Integration | Component | admin-plugins-list-item", function (hooks) {
  setupRenderingTest(hooks);

  function pluginAttrs() {
    return {
      id: "discourse-test-plugin",
      name: "discourse-test-plugin",
      admin_route: {
        location: "discourse-test-plugin",
        label: "admin.plugins.title",
        use_new_show_route: false,
        full_location: "admin",
      },
      has_settings: true,
      has_only_enabled_setting: false,
    };
  }

  test("settings link route", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    const store = getOwner(this).lookup("service:store");
    this.plugin = store.createRecord("admin-plugin", pluginAttrs());

    await render(
      <template><AdminPluginsListItem @plugin={{self.plugin}} /></template>
    );

    assert
      .dom(".admin-plugins-list__settings a")
      .hasAttribute(
        "href",
        "/admin/site_settings/category/plugins?filter=plugin%3Adiscourse-test-plugin"
      );

    this.plugin.adminRoute.use_new_show_route = true;
    await render(
      <template><AdminPluginsListItem @plugin={{self.plugin}} /></template>
    );

    assert
      .dom(".admin-plugins-list__settings a")
      .hasAttribute("href", "/admin/plugins/discourse-test-plugin");
  });

  test("settings link show or hide", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    const store = getOwner(this).lookup("service:store");
    this.plugin = store.createRecord("admin-plugin", pluginAttrs());

    await render(
      <template><AdminPluginsListItem @plugin={{self.plugin}} /></template>
    );

    assert.dom(".admin-plugins-list__settings a").exists();

    this.plugin.hasSettings = false;
    await render(
      <template><AdminPluginsListItem @plugin={{self.plugin}} /></template>
    );
    assert.dom(".admin-plugins-list__settings a").doesNotExist();
  });

  test("settings link disabled if only the enabled setting exists", async function (assert) {
    const self = this;

    this.currentUser.admin = true;
    const store = getOwner(this).lookup("service:store");
    this.plugin = store.createRecord("admin-plugin", pluginAttrs());

    await render(
      <template><AdminPluginsListItem @plugin={{self.plugin}} /></template>
    );

    assert.dom(".admin-plugins-list__settings a.disabled").doesNotExist();

    this.plugin.hasOnlyEnabledSetting = true;
    await render(
      <template><AdminPluginsListItem @plugin={{self.plugin}} /></template>
    );
    assert.dom(".admin-plugins-list__settings a.disabled").exists();
  });
});
