import I18n from "I18n";

import { test } from "qunit";

import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";

acceptance("Sidebar - Anonymous user - Community Section", function (needs) {
  needs.settings({
    enable_experimental_sidebar_hamburger: true,
    enable_sidebar: true,
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

  test("groups  and badges section links are shown in more...", async function (assert) {
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
