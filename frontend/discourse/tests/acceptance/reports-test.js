import { click, currentURL, fillIn, select, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Reports", function (needs) {
  needs.user();

  test("Visit reports page", async function (assert) {
    await visit("/admin/reports");

    assert
      .dom(".admin-reports-list .admin-section-landing-item__content")
      .exists({ count: 1 });

    assert
      .dom(
        ".admin-reports-list .admin-section-landing-item__content .admin-section-landing-item__title"
      )
      .hasHtml("My report");

    assert
      .dom(
        ".admin-reports-list .admin-section-landing-item__content .admin-section-landing-item__description"
      )
      .hasHtml("List of my activities");
  });

  test("Visit report page", async function (assert) {
    await visit("/admin/reports/admin_logins");

    assert.dom(".export-csv-btn").exists();
  });
});

acceptance("Reports | Plugin groups sorted by display name", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/admin/reports", () => {
      return helper.response({
        reports: [
          {
            title: "Zebra Report",
            description: "From zebra plugin",
            type: "zebra_report",
            plugin: "zebra-plugin",
            plugin_display_name: "Zebra Analytics",
          },
          {
            title: "Alpha Report",
            description: "From alpha plugin",
            type: "alpha_report",
            plugin: "alpha-plugin",
            plugin_display_name: "Alpha Metrics",
          },
          {
            title: "Middle Report",
            description: "From middle plugin",
            type: "middle_report",
            plugin: "middle-plugin",
            plugin_display_name: "Middle Stats",
          },
        ],
      });
    });
  });

  test("plugin report groups are sorted alphabetically by display name", async function (assert) {
    await visit("/admin/reports");

    const groupTitles = [
      ...document.querySelectorAll(".admin-reports-group__title"),
    ].map((el) => el.textContent.trim());

    assert.deepEqual(groupTitles, [
      "Alpha Metrics",
      "Middle Stats",
      "Zebra Analytics",
    ]);
  });
});

acceptance("Reports | Filter query params", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/admin/reports", () => {
      return helper.response({
        reports: [
          {
            title: "Signups",
            description: "New account creations",
            type: "signups",
          },
          {
            title: "Topics",
            description: "New topics of all statuses",
            type: "topics",
          },
          {
            title: "Flags",
            description: "Number of flags created",
            type: "flags",
          },
        ],
      });
    });
  });

  test("typing in the filter box reflects the search in the URL", async function (assert) {
    await visit("/admin/reports");

    await fillIn(".admin-filter-controls__input", "signups");

    assert.strictEqual(
      currentURL(),
      "/admin/reports?filter=signups",
      "writes the text filter to the URL"
    );
    assert.dom(".admin-section-landing-item__content").exists({ count: 1 });
    assert
      .dom(".admin-section-landing-item__title")
      .hasHtml("Signups", "only shows the matching report");
    assert
      .dom(".admin-filter-controls__input")
      .isFocused("keeps focus while the URL updates");

    await fillIn(".admin-filter-controls__input", "");

    assert.strictEqual(
      currentURL(),
      "/admin/reports",
      "clearing the search removes the param"
    );
    assert.dom(".admin-section-landing-item__content").exists({ count: 3 });
  });

  test("selecting a group reflects it in the URL", async function (assert) {
    await visit("/admin/reports");

    await select(".admin-filter-controls__dropdown", "moderation_and_security");

    assert.strictEqual(
      currentURL(),
      "/admin/reports?group=moderation_and_security",
      "writes the group to the URL"
    );
    assert.dom(".admin-reports-group").exists({ count: 1 });
    assert.dom(".admin-section-landing-item__content").exists({ count: 1 });

    await select(".admin-filter-controls__dropdown", "all");

    assert.strictEqual(
      currentURL(),
      "/admin/reports",
      "selecting all groups removes the param"
    );
    assert.dom(".admin-reports-group").exists({ count: 3 });
  });

  test("pre-selects the group from the URL", async function (assert) {
    await visit("/admin/reports?group=content");

    assert.strictEqual(currentURL(), "/admin/reports?group=content");
    assert.dom(".admin-filter-controls__dropdown").hasValue("content");
    assert.dom(".admin-reports-group").exists({ count: 1 });
    assert
      .dom(".admin-section-landing-item__title")
      .hasHtml("Topics", "only shows reports from the group in the URL");
  });

  test("re-derives the group when the URL changes without leaving the route", async function (assert) {
    // e.g. clicking a link that carries a different ?group= while already on
    // the page; removing the params entirely is not covered because a
    // same-route transition to the bare URL fires no route event at all
    await visit("/admin/reports?group=content");

    assert.dom(".admin-filter-controls__dropdown").hasValue("content");

    await visit("/admin/reports?group=moderation_and_security");

    assert
      .dom(".admin-filter-controls__dropdown")
      .hasValue(
        "moderation_and_security",
        "re-selects the dropdown from the new URL"
      );
    assert
      .dom(".admin-section-landing-item__title")
      .hasHtml("Flags", "re-filters to the new group");
  });

  test("falls back to all groups when the URL group is unknown", async function (assert) {
    await visit("/admin/reports?group=nonsense");

    assert.dom(".admin-filter-controls__dropdown").hasValue("all");
    assert.dom(".admin-reports-group").exists({ count: 3 });
    assert.dom(".admin-section-landing-item__content").exists({ count: 3 });
  });

  test("reset button clears both params from the URL", async function (assert) {
    await visit("/admin/reports");

    await fillIn(".admin-filter-controls__input", "signups");
    await select(".admin-filter-controls__dropdown", "engagement");

    assert.strictEqual(
      currentURL(),
      "/admin/reports?filter=signups&group=engagement",
      "both filters are in the URL"
    );

    await click(".admin-filter-controls__reset");

    assert.strictEqual(
      currentURL(),
      "/admin/reports",
      "clears both params in one write"
    );
    assert.dom(".admin-filter-controls__input").hasValue("");
    assert.dom(".admin-filter-controls__dropdown").hasValue("all");
    assert.dom(".admin-section-landing-item__content").exists({ count: 3 });
  });
});
