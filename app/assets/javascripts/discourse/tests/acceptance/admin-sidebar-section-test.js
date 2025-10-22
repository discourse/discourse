import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { withPluginApi } from "discourse/lib/plugin-api";
import PreloadStore from "discourse/lib/preload-store";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Admin Sidebar - Sections", function (needs) {
  needs.user({
    admin: true,
    groups: [AUTO_GROUPS.admins],
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

    pretender.get("/admin/config/site_settings.json", () =>
      response({
        site_settings: [],
      })
    );
  });

  test("default sections are loaded", async function (assert) {
    await visit("/admin");

    assert
      .dom(".sidebar-section[data-section-name='admin-root']")
      .exists("root section is displayed");
    assert
      .dom(".sidebar-section[data-section-name='admin-reports']")
      .exists("reports section is displayed");
    assert
      .dom(".sidebar-section[data-section-name='admin-community']")
      .exists("community section is displayed");
    assert
      .dom(".sidebar-section[data-section-name='admin-appearance']")
      .exists("appearance section is displayed");
    assert
      .dom(".sidebar-section[data-section-name='admin-email_settings']")
      .exists("email settings section is displayed");
    assert
      .dom(".sidebar-section[data-section-name='admin-security']")
      .exists("security settings section is displayed");
    assert
      .dom(".sidebar-section[data-section-name='admin-plugins']")
      .exists("plugins section is displayed");
    assert
      .dom(".sidebar-section[data-section-name='admin-advanced']")
      .exists("advanced section is displayed");
  });

  test("enabled plugin admin routes have links added", async function (assert) {
    await visit("/admin");
    await click(".sidebar-toggle-all-sections");

    assert
      .dom(
        ".sidebar-section[data-section-name='admin-plugins'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_installed_plugins\"]"
      )
      .exists("the admin plugin route is added to the plugins section");
  });

  test("Visit reports page", async function (assert) {
    await visit("/admin");
    await click(".sidebar-toggle-all-sections");
    await click(".sidebar-section-link[data-link-name='admin_all_reports']");

    assert
      .dom(".admin-reports-list .admin-section-landing-item__content")
      .exists({ count: 1 });

    await fillIn(".admin-filter-controls__input", "flags");

    assert
      .dom(".admin-reports-list .admin-section-landing-item__content")
      .doesNotExist();

    await click(".sidebar-section-link[data-link-name='admin_login']");
    await click(".sidebar-section-link[data-link-name='admin_all_reports']");

    assert
      .dom(".admin-reports-list .admin-section-landing-item__content")
      .exists({ count: 1 }, "navigating back and forth resets filter");

    await fillIn(".admin-filter-controls__input", "activities");

    assert
      .dom(".admin-reports-list .admin-section-landing-item__content")
      .exists({ count: 1 }, "filter is case insensitive");
  });
});

acceptance("Admin Sidebar - Sections - Plugin API", function (needs) {
  needs.user({
    admin: true,
    groups: [AUTO_GROUPS.admins],
  });

  needs.hooks.beforeEach(() => {
    withPluginApi((api) => {
      api.addAdminSidebarSectionLink("root", {
        name: "test_section_link",
        label: "admin.plugins.title",
        route: "adminPlugins.index",
        icon: "gear",
      });

      api.addAdminSidebarSectionLink("root", {
        name: "test_section_link_no_route_or_href",
        label: "admin.plugins.title",
        icon: "gear",
      });

      api.addAdminSidebarSectionLink("root", {
        name: "test_section_link_no_label_or_text",
        route: "adminPlugins.index",
        icon: "gear",
      });

      api.addAdminSidebarSectionLink("root", {
        name: "test_section_link_invalid_label",
        label: "blahblah.i18n",
        route: "adminPlugins.index",
        icon: "gear",
      });

      api.addCommunitySectionLink(
        {
          name: "primary",
          route: "discovery.unread",
          title: "Link in primary",
          text: "Link in primary",
        },
        false
      );

      api.addCommunitySectionLink(
        {
          name: "secondary",
          route: "discovery.unread",
          title: "Link in secondary",
          text: "Link in secondary",
        },
        true
      );
    });
  });

  test("additional valid links can be added to a section with the plugin API", async function (assert) {
    await visit("/admin");

    assert
      .dom(
        ".sidebar-section[data-section-name='admin-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link\"]"
      )
      .exists("link is appended to the root section");

    assert
      .dom(
        ".sidebar-section[data-section-name='admin-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link_no_route_or_href\"]"
      )
      .doesNotExist(
        "invalid link that has no route or href is not appended to the root section"
      );

    assert
      .dom(
        ".sidebar-section[data-section-name='admin-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link_no_label_or_text\"]"
      )
      .doesNotExist(
        "invalid link that has no label or text is not appended to the root section"
      );

    assert
      .dom(
        ".sidebar-section[data-section-name='admin-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link_invalid_label\"]"
      )
      .doesNotExist(
        "invalid link with an invalid I18n key is not appended to the root section"
      );
  });

  test("community section links are added to primary and secondary sections with the plugin API", async function (assert) {
    await visit("/");

    assert
      .dom(
        "#sidebar-section-content-community .sidebar-section-link[data-link-name='primary']"
      )
      .exists();
    assert
      .dom(
        "#sidebar-section-content-community .sidebar-section-link[data-link-name='secondary']"
      )
      .doesNotExist();

    await click(".sidebar-more-section-trigger");

    assert
      .dom(
        "sidebar-more-section-content .sidebar-section-link[data-link-name='primary']"
      )
      .doesNotExist();
    assert
      .dom(
        ".sidebar-more-section-content .sidebar-section-link[data-link-name='secondary']"
      )
      .exists();
  });
});

let _locale;
acceptance(
  "Admin Sidebar - Sections - Plugin API - Translation Fallbacks",
  function (needs) {
    needs.user({
      admin: true,
      groups: [AUTO_GROUPS.admins],
    });

    needs.hooks.beforeEach(() => {
      _locale = I18n.locale;
      I18n.locale = "fr_FOO";

      withPluginApi((api) => {
        api.addAdminSidebarSectionLink("root", {
          name: "test_section_link",
          label: "admin.plugins.title",
          route: "adminPlugins.index",
          icon: "gear",
        });
      });
    });

    needs.hooks.afterEach(() => {
      I18n.locale = _locale;
    });

    test("valid links that are yet to be translated can be added to a section with the plugin API because of I18n fallback", async function (assert) {
      await visit("/admin");

      assert
        .dom(
          ".sidebar-section[data-section-name='admin-root'] .sidebar-section-link-wrapper[data-list-item-name=\"admin_additional_root_test_section_link\"]"
        )
        .exists("link is appended to the root section");
    });
  }
);
