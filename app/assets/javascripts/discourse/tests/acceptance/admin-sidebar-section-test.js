import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { withPluginApi } from "discourse/lib/plugin-api";
import PreloadStore from "discourse/lib/preload-store";
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";

acceptance("Admin Sidebar - Sections", function (needs) {
  needs.user({
    admin: true,
    groups: [AUTO_GROUPS.admins],
    use_admin_sidebar: true,
  });

  needs.hooks.beforeEach(() => {
    PreloadStore.store("enabledPluginAdminRoutes", [
      {
        location: "index",
        label: "admin.plugins.title",
      },
    ]);
  });

  test("default sections are loaded", async function (assert) {
    await visit("/admin");

    assert.ok(
      exists(".sidebar-section[data-section-name='admin-nav-section-root']"),
      "root section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-nav-section-plugins']"),
      "plugins section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-nav-section-email']"),
      "email section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-nav-section-logs']"),
      "logs section is displayed"
    );
    assert.ok(
      exists(
        ".sidebar-section[data-section-name='admin-nav-section-customize']"
      ),
      "customize section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-nav-section-api']"),
      "api section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-nav-section-backups']"),
      "backups section is displayed"
    );
  });

  test("enabled plugin admin routes have links added", async function (assert) {
    await visit("/admin");

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='admin-nav-section-plugins'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_plugin_index\"]"
      ),
      "the admin plugin route is added to the plugins section"
    );
  });
});

acceptance("Admin Sidebar - Sections - Plugin API", function (needs) {
  needs.user({
    admin: true,
    groups: [AUTO_GROUPS.admins],
    use_admin_sidebar: true,
  });

  needs.hooks.beforeEach(() => {
    withPluginApi("1.24.0", (api) => {
      api.addAdminSidebarSectionLink("root", {
        name: "test_section_link",
        label: "admin.plugins.title",
        route: "adminPlugins.index",
        icon: "cog",
      });

      api.addAdminSidebarSectionLink("root", {
        name: "test_section_link_no_route_or_href",
        label: "admin.plugins.title",
        icon: "cog",
      });

      api.addAdminSidebarSectionLink("root", {
        name: "test_section_link_no_label_or_text",
        route: "adminPlugins.index",
        icon: "cog",
      });

      api.addAdminSidebarSectionLink("root", {
        name: "test_section_link_invalid_label",
        label: "blahblah.i18n",
        route: "adminPlugins.index",
        icon: "cog",
      });
    });
  });

  test("additional valid links can be added to a section with the plugin API", async function (assert) {
    await visit("/admin");

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='admin-nav-section-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link\"]"
      ),
      "link is appended to the root section"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='admin-nav-section-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link_no_route_or_href\"]"
      ),
      "invalid link that has no route or href is not appended to the root section"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='admin-nav-section-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link_no_label_or_text\"]"
      ),
      "invalid link that has no label or text is not appended to the root section"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='admin-nav-section-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link_invalid_label\"]"
      ),
      "invalid link with an invalid I18n key is not appended to the root section"
    );
  });
});
