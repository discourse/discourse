import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { withPluginApi } from "discourse/lib/plugin-api";
import PreloadStore from "discourse/lib/preload-store";
import {
  acceptance,
  count,
  exists,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Admin Sidebar - Sections", function (needs) {
  needs.user({
    admin: true,
    groups: [AUTO_GROUPS.admins],
    use_admin_sidebar: true,
  });

  needs.hooks.beforeEach(() => {
    PreloadStore.store("visiblePlugins", [
      {
        name: "plugin title",
        admin_route: {
          location: "index",
          label: "admin.plugins.title",
          enabled: true,
        },
      },
    ]);
  });

  test("default sections are loaded", async function (assert) {
    await visit("/admin");

    assert.ok(
      exists(".sidebar-section[data-section-name='admin-root']"),
      "root section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-account']"),
      "account section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-reports']"),
      "reports section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-community']"),
      "community section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-appearance']"),
      "appearance section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-email_settings']"),
      "email settings section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-email_logs']"),
      "email logs settings section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-security']"),
      "security settings section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-plugins']"),
      "plugins section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-advanced']"),
      "advanced section is displayed"
    );
  });

  test("filter sections and clear filter with ESC", async function (assert) {
    await visit("/admin");
    await fillIn(".sidebar-filter__input", "advanced");
    assert.notOk(
      exists(".sidebar-section[data-section-name='admin-plugins']"),
      "plugins section is hidden"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-advanced']"),
      "advanced section is displayed"
    );

    await triggerKeyEvent(".sidebar-filter__input", "keydown", "Escape");
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-plugins']"),
      "plugins section is displayed"
    );
    assert.ok(
      exists(".sidebar-section[data-section-name='admin-advanced']"),
      "advanced section is displayed"
    );
  });

  test("enabled plugin admin routes have links added", async function (assert) {
    await visit("/admin");
    await click(".sidebar-toggle-all-sections");

    assert.ok(
      exists(
        ".sidebar-section[data-section-name='admin-plugins'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_installed_plugins\"]"
      ),
      "the admin plugin route is added to the plugins section"
    );
  });

  test("Visit reports page", async function (assert) {
    await visit("/admin");
    await click(".sidebar-toggle-all-sections");
    await click(".sidebar-section-link[data-link-name='admin_all_reports']");

    assert.strictEqual(count(".admin-reports-list__report"), 1);

    await fillIn(".admin-reports-header__filter", "flags");

    assert.strictEqual(count(".admin-reports-list__report"), 0);

    await click(
      ".sidebar-section-link[data-link-name='admin_about_your_site']"
    );
    await click(".sidebar-section-link[data-link-name='admin_all_reports']");

    assert.strictEqual(
      count(".admin-reports-list__report"),
      1,
      "navigating back and forth resets filter"
    );

    await fillIn(".admin-reports-header__filter", "activities");

    assert.strictEqual(
      count(".admin-reports-list__report"),
      1,
      "filter is case insensitive"
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
        ".sidebar-section[data-section-name='admin-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link\"]"
      ),
      "link is appended to the root section"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='admin-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link_no_route_or_href\"]"
      ),
      "invalid link that has no route or href is not appended to the root section"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='admin-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link_no_label_or_text\"]"
      ),
      "invalid link that has no label or text is not appended to the root section"
    );

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='admin-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link_invalid_label\"]"
      ),
      "invalid link with an invalid I18n key is not appended to the root section"
    );
  });
});

let _locale;
acceptance(
  "Admin Sidebar - Sections - Plugin API - Translation Fallbacks",
  function (needs) {
    needs.user({
      admin: true,
      groups: [AUTO_GROUPS.admins],
      use_admin_sidebar: true,
    });

    needs.hooks.beforeEach(() => {
      _locale = I18n.locale;
      I18n.locale = "fr_FOO";

      withPluginApi("1.24.0", (api) => {
        api.addAdminSidebarSectionLink("root", {
          name: "test_section_link",
          label: "admin.plugins.title",
          route: "adminPlugins.index",
          icon: "cog",
        });
      });
    });

    needs.hooks.afterEach(() => {
      I18n.locale = _locale;
    });

    test("valid links that are yet to be translated can be added to a section with the plugin API because of I18n fallback", async function (assert) {
      await visit("/admin");

      assert.ok(
        exists(
          ".sidebar-section[data-section-name='admin-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link\"]"
        ),
        "link is appended to the root section"
      );
    });
  }
);
