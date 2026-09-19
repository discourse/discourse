import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminPluginsListItem from "discourse/admin/components/admin-plugins-list-item";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | AdminPluginsListItem", function (hooks) {
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
    this.currentUser.admin = true;
    const store = getOwner(this).lookup("service:store");
    this.plugin = store.createRecord("admin-plugin", pluginAttrs());

    await render(
      <template><AdminPluginsListItem @plugin={{this.plugin}} /></template>
    );

    assert
      .dom(".admin-plugins-list__settings a")
      .hasAttribute(
        "href",
        "/admin/site_settings/category/plugins?filter=plugin%3Adiscourse-test-plugin"
      );

    this.plugin.adminRoute.use_new_show_route = true;
    await render(
      <template><AdminPluginsListItem @plugin={{this.plugin}} /></template>
    );

    assert
      .dom(".admin-plugins-list__settings a")
      .hasAttribute("href", "/admin/plugins/discourse-test-plugin");
  });

  test("name links to the plugin's own route when it predates the show route", async function (assert) {
    this.currentUser.admin = true;
    const store = getOwner(this).lookup("service:store");
    // `full_location` stands in for a route the plugin registers itself; it
    // only has to resolve for the link to be built.
    this.plugin = store.createRecord("admin-plugin", pluginAttrs());

    await render(
      <template><AdminPluginsListItem @plugin={{this.plugin}} /></template>
    );

    assert.dom("a.admin-plugins-list__name").hasAttribute("href", "/admin");

    this.plugin.adminRoute = null;
    await render(
      <template><AdminPluginsListItem @plugin={{this.plugin}} /></template>
    );

    assert
      .dom("a.admin-plugins-list__name")
      .hasAttribute(
        "href",
        "/admin/site_settings/category/plugins?filter=plugin%3Adiscourse-test-plugin",
        "falls back to the settings category when the plugin has no route of its own"
      );
  });

  test("settings link show or hide", async function (assert) {
    this.currentUser.admin = true;
    const store = getOwner(this).lookup("service:store");
    this.plugin = store.createRecord("admin-plugin", pluginAttrs());

    await render(
      <template><AdminPluginsListItem @plugin={{this.plugin}} /></template>
    );

    assert.dom(".admin-plugins-list__settings a").exists();

    this.plugin.hasSettings = false;
    await render(
      <template><AdminPluginsListItem @plugin={{this.plugin}} /></template>
    );
    assert.dom(".admin-plugins-list__settings a").doesNotExist();
  });

  test("settings link disabled if only the enabled setting exists", async function (assert) {
    this.currentUser.admin = true;
    const store = getOwner(this).lookup("service:store");
    this.plugin = store.createRecord("admin-plugin", pluginAttrs());

    await render(
      <template><AdminPluginsListItem @plugin={{this.plugin}} /></template>
    );

    assert.dom(".admin-plugins-list__settings a.disabled").doesNotExist();

    this.plugin.hasOnlyEnabledSetting = true;
    await render(
      <template><AdminPluginsListItem @plugin={{this.plugin}} /></template>
    );
    assert.dom(".admin-plugins-list__settings a.disabled").exists();
  });
});
