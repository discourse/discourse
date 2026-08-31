import { click, render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminReportTableSummary from "discourse/admin/components/admin-report-table-summary";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | AdminReportTableSummary", function (hooks) {
  setupRenderingTest(hooks);

  test("loads and displays users for the selected day", async function (assert) {
    let requestParams;

    pretender.get("/admin/reports/signups", (request) => {
      requestParams = request.queryParams;

      return response({
        report: {
          related_items: {
            users: [
              {
                user: {
                  id: 1,
                  username: "dana_whitfield",
                  name: "Dana Whitfield",
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/d/3be4f0/{size}.png",
                },
              },
            ],
          },
          related_items_totals: { users: 3 },
        },
      });
    });

    await render(
      <template>
        <AdminReportTableSummary
          @date="2026-08-18"
          @formattedValue="3"
          @reportType="signups"
        />
      </template>
    );

    assert
      .dom(".admin-report-table-summary")
      .doesNotHaveClass("btn", "does not use generic button styling");
    assert
      .dom(".admin-report-table-summary")
      .hasAttribute(
        "aria-label",
        "Show summary for Aug 18, 2026",
        "has an accessible label"
      );

    triggerEvent(".admin-report-table-summary", "pointerenter");
    await settled();

    assert
      .dom(".admin-report-table-summary__heading")
      .hasText("Users on Aug 18, 2026", "labels the selected day");
    assert
      .dom(".admin-report-table-summary__user-link")
      .hasAttribute("href", "/u/dana_whitfield", "links to the user profile");
    assert
      .dom(".admin-report-table-summary__user-link")
      .doesNotHaveAttribute("data-user-card", "does not open a user card");
    assert
      .dom(".admin-report-table-summary__limit")
      .hasText(
        "Showing the newest 1 of 3.",
        "discloses that the list is limited"
      );
    assert.strictEqual(
      requestParams.cache,
      undefined,
      "does not request caching for the related-item payload"
    );
    assert.strictEqual(
      requestParams.include_related_items,
      "true",
      "requests the related-item payload"
    );
    assert.deepEqual(
      requestParams.facets,
      ["related_items"],
      "requests only the related-items facet"
    );
  });

  test("retries loading after an error", async function (assert) {
    let requestCount = 0;

    pretender.get("/admin/reports/signups", () => {
      requestCount++;

      if (requestCount === 1) {
        return response(500, {});
      }

      return response({
        report: {
          related_items: {
            users: [
              {
                user: {
                  id: 1,
                  username: "dana_whitfield",
                  avatar_template:
                    "/letter_avatar_proxy/v4/letter/d/3be4f0/{size}.png",
                },
              },
            ],
          },
        },
      });
    });

    await render(
      <template>
        <AdminReportTableSummary
          @date="2026-08-18"
          @formattedValue="3"
          @reportType="signups"
        />
      </template>
    );

    await click(".admin-report-table-summary");

    assert
      .dom(".admin-report-table-summary__message")
      .hasText("Couldn't load the summary.", "shows the failed request state");

    await click(".admin-report-table-summary");
    await click(".admin-report-table-summary");

    assert.strictEqual(requestCount, 2, "retries when the menu reopens");
    assert
      .dom(".admin-report-table-summary__user-link")
      .hasAttribute("href", "/u/dana_whitfield", "shows the retried response");
  });
});
