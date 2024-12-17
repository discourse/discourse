import { click, findAll, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";

acceptance("Styleguide Smoke Test", function (needs) {
  needs.settings({ chat_enabled: true });
  needs.user({
    admin: true,
    user_option: {
      chat_enabled: true,
    },
  });

  test("renders the index page correctly and collects information about the available pages", async function (assert) {
    await visit("/styleguide");
    assert.dom(".styleguide-contents h1.section-title").hasText("Styleguide");

    const existingSections = {};
    const sectionNodes = findAll(".styleguide-menu > ul");

    sectionNodes.forEach((sectionNode) => {
      const section = sectionNode
        .querySelector(".styleguide-heading")
        .textContent.trim();
      existingSections[section] = [];
      const anchors = sectionNode.querySelectorAll("li a");

      anchors.forEach((anchor) => {
        existingSections[section].push({
          title: anchor.textContent.trim(),
          href: anchor.getAttribute("href"),
          anchor,
        });
      });
    });

    let oldHeading = null,
      oldSection = null;

    for (const [section, items] of Object.entries(existingSections)) {
      for (const item of items) {
        await click(item.anchor);

        const heading = query(
          ".styleguide-contents h1.section-title"
        ).textContent.trim();
        const headingWasUpdated = oldHeading !== heading;

        assert.ok(
          heading === item.title,
          `Page was updated to ${section} > ${item.title}` +
            (headingWasUpdated
              ? ""
              : ` (The error is probably located in ${oldSection} > ${oldHeading})`)
        );

        if (headingWasUpdated) {
          oldHeading = item.title;
          oldSection = section;
        }
      }
    }

    // Return to the index page to test if the application is able to navigate away from the last component
    await visit("/styleguide");
    assert
      .dom(".styleguide-contents h1.section-title")
      .hasText(
        "Styleguide",
        `Navigated back to the home page from ${oldSection} > ${oldHeading}`
      );
  });
});
