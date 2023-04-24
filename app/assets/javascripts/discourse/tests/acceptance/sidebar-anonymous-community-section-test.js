import I18n from "I18n";

import { test } from "qunit";

import {
  acceptance,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";

acceptance("Sidebar - Anonymous user - Community Section", function (needs) {
  needs.settings({
    navigation_menu: "sidebar",
    faq_url: "https://discourse.org",
  });
  needs.site({
    anonymous_sidebar_sections: [
      {
        id: 111,
        title: "community",
        links: [
          {
            id: 329,
            name: "everything",
            value: "/latest",
            icon: "layer-group",
            external: false,
            segment: "primary",
          },
          {
            id: 330,
            name: "users",
            value: "/u",
            icon: "users",
            external: false,
            segment: "secondary",
          },
          {
            id: 331,
            name: "info",
            value: "/about",
            icon: "info-circle",
            external: false,
            segment: "secondary",
          },
          {
            id: 332,
            name: "faq",
            value: "/faq",
            icon: "question-circle",
            external: false,
            segment: "secondary",
          },
          {
            id: 333,
            name: "my_posts",
            value: "/my/activity",
            icon: "user",
            external: false,
            segment: "primary",
          },
          {
            id: 334,
            name: "review",
            value: "/review",
            icon: "flag",
            external: false,
            segment: "secondary",
          },
          {
            id: 335,
            name: "admin",
            value: "/admin",
            icon: "wrench",
            external: false,
            segment: "primary",
          },
          {
            id: 336,
            name: "groups",
            value: "/g",
            icon: "user-friends",
            external: false,
            segment: "secondary",
          },
          {
            id: 337,
            name: "badges",
            value: "/badges",
            icon: "certificate",
            external: false,
            segment: "secondary",
          },
        ],
        slug: "community",
        public: true,
        system: true,
      },
    ],
  });

  test("display short site description site setting when it is set", async function (assert) {
    this.siteSettings.short_site_description =
      "This is a short description about the site";

    await visit("/");

    assert.strictEqual(
      query(
        ".sidebar-section[data-section-name='community'] .sidebar-section-message"
      ).textContent.trim(),
      this.siteSettings.short_site_description,
      "displays the short site description under the community section"
    );
  });

  test("everything section link is shown by default ", async function (assert) {
    await visit("/");

    const sectionLinks = queryAll(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link"
    );

    assert.strictEqual(
      sectionLinks[0].textContent.trim(),
      I18n.t("sidebar.sections.community.links.everything.content"),
      "displays the everything section link first"
    );
  });

  test("users section link is not shown when hide_user_profiles_from_public site setting is enabled", async function (assert) {
    this.siteSettings.hide_user_profiles_from_public = true;

    await visit("/");

    assert.notOk(
      exists(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='users']"
      ),
      "users section link is not shown in sidebar"
    );
  });

  test("users, about, faq, groups and badges section links are shown in more...", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-links-details-summary"
    );

    const sectionLinks = queryAll(
      ".sidebar-more-section-links-details-content-main .sidebar-section-link"
    );

    assert.strictEqual(
      sectionLinks[0].textContent.trim(),
      I18n.t("sidebar.sections.community.links.users.content"),
      "displays the users section link second"
    );

    assert.strictEqual(
      sectionLinks[1].textContent.trim(),
      I18n.t("sidebar.sections.community.links.about.content"),
      "displays the about section link third"
    );

    assert.strictEqual(
      sectionLinks[2].textContent.trim(),
      I18n.t("sidebar.sections.community.links.faq.content"),
      "displays the FAQ section link last"
    );

    assert.strictEqual(
      sectionLinks[3].textContent.trim(),
      I18n.t("sidebar.sections.community.links.groups.content"),
      "displays the groups section link first"
    );

    assert.strictEqual(
      sectionLinks[4].textContent.trim(),
      I18n.t("sidebar.sections.community.links.badges.content"),
      "displays the badges section link second"
    );
  });
});
