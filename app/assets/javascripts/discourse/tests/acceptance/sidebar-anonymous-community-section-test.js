import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";

acceptance("Sidebar - Anonymous user - Community Section", function (needs) {
  needs.settings({
    navigation_menu: "sidebar",
    faq_url: "https://discourse.org",
  });

  needs.site({});

  test("topics section link is shown by default ", async function (assert) {
    await visit("/");

    const sectionLinks = queryAll(
      ".sidebar-section[data-section-name='community'] .sidebar-section-link"
    );

    assert.strictEqual(
      sectionLinks[0].textContent.trim(),
      I18n.t("sidebar.sections.community.links.topics.content"),
      "displays the topics section link first"
    );
  });

  test("users section link is not shown when hide_user_profiles_from_public site setting is enabled", async function (assert) {
    this.siteSettings.hide_user_profiles_from_public = true;

    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link[data-link-name='users']"
      )
      .doesNotExist("users section link is not shown in sidebar");
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
