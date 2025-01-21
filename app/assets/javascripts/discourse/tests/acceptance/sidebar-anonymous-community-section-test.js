import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Sidebar - Anonymous user - Community Section", function (needs) {
  needs.settings({
    navigation_menu: "sidebar",
    faq_url: "https://discourse.org",
  });

  needs.site({});

  test("topics section link is shown by default ", async function (assert) {
    await visit("/");

    assert
      .dom(
        ".sidebar-section[data-section-name='community'] .sidebar-section-link"
      )
      .hasText(
        i18n("sidebar.sections.community.links.topics.content"),
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
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-trigger"
    );

    const sectionLinks = queryAll(
      ".sidebar-more-section-content .sidebar-section-link"
    );

    assert
      .dom(sectionLinks[0])
      .hasText(
        i18n("sidebar.sections.community.links.users.content"),
        "displays the users section link second"
      );

    assert
      .dom(sectionLinks[1])
      .hasText(
        i18n("sidebar.sections.community.links.about.content"),
        "displays the about section link third"
      );

    assert
      .dom(sectionLinks[2])
      .hasText(
        i18n("sidebar.sections.community.links.faq.content"),
        "displays the FAQ section link last"
      );

    assert
      .dom(sectionLinks[3])
      .hasText(
        i18n("sidebar.sections.community.links.groups.content"),
        "displays the groups section link first"
      );

    assert
      .dom(sectionLinks[4])
      .hasText(
        i18n("sidebar.sections.community.links.badges.content"),
        "displays the badges section link second"
      );
  });
});

acceptance(
  "Sidebar - Anonymous user - Community Section with hidden links",
  function (needs) {
    needs.settings({ navigation_menu: "sidebar" });

    needs.site({
      anonymous_sidebar_sections: [
        {
          id: 1,
          title: "The A Team",
          section_type: "community",
          links: [
            {
              id: 2,
              name: "Admin",
              value: "/admin",
              segment: "secondary",
            },
          ],
        },
      ],
    });

    test("more... is not shown when there are no displayable links", async function (assert) {
      await visit("/");

      assert.dom(".sidebar-more-section-links-details-summary").doesNotExist();
    });
  }
);
