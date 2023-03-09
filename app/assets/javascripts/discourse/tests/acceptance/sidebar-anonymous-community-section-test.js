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

  test("display short site description site setting when it is set", async function (assert) {
    this.siteSettings.short_site_description =
      "This is a short description about the site";

    await visit("/");

    assert.strictEqual(
      query(
        ".sidebar-section-community .sidebar-section-message"
      ).textContent.trim(),
      this.siteSettings.short_site_description,
      "displays the short site description under the community section"
    );

    const sectionLinks = queryAll(
      ".sidebar-section-community .sidebar-section-link"
    );

    assert.strictEqual(
      sectionLinks[0].textContent.trim(),
      I18n.t("sidebar.sections.community.links.about.content"),
      "displays the about section link first"
    );
  });

  test("everything, users, about and FAQ section links are shown by default ", async function (assert) {
    await visit("/");

    const sectionLinks = queryAll(
      ".sidebar-section-community .sidebar-section-link"
    );

    assert.strictEqual(
      sectionLinks[0].textContent.trim(),
      I18n.t("sidebar.sections.community.links.everything.content"),
      "displays the everything section link first"
    );

    assert.strictEqual(
      sectionLinks[1].textContent.trim(),
      I18n.t("sidebar.sections.community.links.users.content"),
      "displays the users section link second"
    );

    assert.strictEqual(
      sectionLinks[2].textContent.trim(),
      I18n.t("sidebar.sections.community.links.about.content"),
      "displays the about section link third"
    );

    assert.strictEqual(
      sectionLinks[3].textContent.trim(),
      I18n.t("sidebar.sections.community.links.faq.content"),
      "displays the FAQ section link last"
    );
  });

  test("users section link is not shown when hide_user_profiles_from_public site setting is enabled", async function (assert) {
    this.siteSettings.hide_user_profiles_from_public = true;

    await visit("/");

    assert.notOk(
      exists(".sidebar-section-community .sidebar-section-link-users"),
      "users section link is not shown in sidebar"
    );
  });

  test("groups and badges section links are shown in more...", async function (assert) {
    await visit("/");

    await click(
      ".sidebar-section-community .sidebar-more-section-links-details-summary"
    );

    const sectionLinks = queryAll(
      ".sidebar-more-section-links-details-content-main .sidebar-section-link"
    );

    assert.strictEqual(
      sectionLinks[0].textContent.trim(),
      I18n.t("sidebar.sections.community.links.groups.content"),
      "displays the groups section link first"
    );

    assert.strictEqual(
      sectionLinks[1].textContent.trim(),
      I18n.t("sidebar.sections.community.links.badges.content"),
      "displays the badges section link second"
    );
  });
});
