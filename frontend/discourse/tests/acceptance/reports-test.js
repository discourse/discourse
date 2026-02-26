import { visit } from "@ember/test-helpers";
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
    await visit("/admin/reports/staff_logins");

    assert.dom(".export-csv-btn").exists();
  });
});

acceptance("Reports | Plugin groups sorted by display name", function (needs) {
  needs.user();
  needs.settings({ reporting_improvements: true });
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
