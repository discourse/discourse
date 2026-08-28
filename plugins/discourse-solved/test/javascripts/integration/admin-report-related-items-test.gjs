import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AdminReportRelatedItems from "discourse/admin/components/admin-report-related-items";
import { adminReportRelatedItemsRenderer } from "discourse/admin/lib/admin-report-related-items";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import SolvedAdminReportTableSummary from "discourse/plugins/discourse-solved/discourse/components/solved-admin-report-table-summary";

module(
  "Integration | Component | Solved admin report related items",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders the solved-topic detail component registered for the report", async function (assert) {
      this.set("relatedItems", {
        solved_topics: [
          {
            topic: {
              title: "Composer loses draft when switching categories",
              url: "/t/composer-loses-draft-when-switching-categories/1",
            },
            solved_by_users: [
              {
                id: 2,
                username: "priya.n",
                avatar_template:
                  "/letter_avatar_proxy/v4/letter/p/3be4f0/{size}.png",
              },
              {
                id: 3,
                username: "laurenb",
                avatar_template:
                  "/letter_avatar_proxy/v4/letter/l/3be4f0/{size}.png",
              },
            ],
            category: {
              id: 1,
              name: "Support",
              slug: "support",
              color: "0088CC",
            },
          },
        ],
      });
      this.set("relatedItemsTotals", { solved_topics: 3 });

      await render(
        <template>
          <AdminReportRelatedItems
            @relatedItems={{this.relatedItems}}
            @relatedItemsTotals={{this.relatedItemsTotals}}
            @startDate="2026-07-17"
            @endDate="2026-08-18"
            @type="accepted_solutions"
          />
        </template>
      );

      assert
        .dom(".admin-report-related-items h2")
        .hasText("Solved topics", "labels the solved topic list");
      assert
        .dom(".solved-admin-report-related-items__topic-link")
        .hasAttribute(
          "href",
          "/t/composer-loses-draft-when-switching-categories/1",
          "links to the topic"
        );
      assert
        .dom(".solved-admin-report-related-items__solved-by-cell a")
        .exists({ count: 2 }, "shows every answer author");
      assert
        .dom(".solved-admin-report-related-items__solved-by-cell a:first-child")
        .hasAttribute("href", "/u/priya.n", "links to the first answer author");
      assert
        .dom(".solved-admin-report-related-items__solved-by-cell a:last-child")
        .hasAttribute(
          "href",
          "/u/laurenb",
          "links to the second answer author"
        );
      assert
        .dom(".badge-category")
        .includesText("Support", "shows the category");
      assert
        .dom(".admin-report-related-items__limit")
        .hasText(
          "Showing the newest 1 of 3.",
          "discloses that the list is limited"
        );
    });

    test("preserves report dates in positive UTC offsets", async function (assert) {
      this.set("relatedItems", {
        solved_topics: [
          {
            topic: {
              title: "Composer loses draft when switching categories",
              url: "/t/composer-loses-draft-when-switching-categories/1",
            },
            solved_by_users: [],
          },
        ],
      });
      this.set("startDate", moment.parseZone("2026-07-26T00:00:00+08:00"));
      this.set("endDate", moment.parseZone("2026-08-27T00:00:00+08:00"));

      await render(
        <template>
          <AdminReportRelatedItems
            @relatedItems={{this.relatedItems}}
            @startDate={{this.startDate}}
            @endDate={{this.endDate}}
            @type="accepted_solutions"
          />
        </template>
      );

      assert
        .dom(".admin-report-related-items__description")
        .hasText(
          "Topics marked as solved between Jul 26, 2026 and Aug 27, 2026, newest first.",
          "keeps the selected calendar dates"
        );
    });

    test("uses the table summary component registered for the report", async function (assert) {
      pretender.get("/admin/reports/accepted_solutions", () =>
        response({
          report: {
            related_items: {
              solved_topics: [
                {
                  topic: {
                    title: "Composer loses draft when switching categories",
                    url: "/t/composer-loses-draft-when-switching-categories/1",
                  },
                  solved_by_users: [
                    {
                      id: 2,
                      username: "priya.n",
                      avatar_template:
                        "/letter_avatar_proxy/v4/letter/p/3be4f0/{size}.png",
                    },
                    {
                      id: 3,
                      username: "laurenb",
                      avatar_template:
                        "/letter_avatar_proxy/v4/letter/l/3be4f0/{size}.png",
                    },
                  ],
                },
              ],
            },
          },
        })
      );

      const renderer = adminReportRelatedItemsRenderer("accepted_solutions");

      this.set("tableSummaryComponent", renderer.tableSummaryComponent);

      await render(
        <template>
          {{component
            this.tableSummaryComponent
            date="2026-08-18"
            formattedValue="1"
            total=3
          }}
        </template>
      );

      await click(".admin-report-table-summary");

      assert.strictEqual(
        renderer.tableSummaryComponent,
        SolvedAdminReportTableSummary,
        "uses the registered Solved component"
      );
      assert
        .dom(".admin-report-table-summary__heading")
        .hasText("Solved topics on Aug 18, 2026", "labels the selected day");
      assert
        .dom(".solved-admin-report-table-summary__topic-link")
        .hasAttribute(
          "href",
          "/t/composer-loses-draft-when-switching-categories/1",
          "links to the solved topic"
        );
      assert
        .dom(".admin-report-table-summary__user-link")
        .exists({ count: 2 }, "shows every answer author");
      assert
        .dom(".admin-report-table-summary__limit")
        .hasText(
          "Showing the newest 1 of 3.",
          "discloses that the list is limited"
        );
    });

    test("retries the table summary after an error", async function (assert) {
      let requestCount = 0;

      pretender.get("/admin/reports/accepted_solutions", () => {
        requestCount++;

        if (requestCount === 1) {
          return response(500, {});
        }

        return response({
          report: {
            related_items: {
              solved_topics: [
                {
                  topic: {
                    title: "Composer loses draft when switching categories",
                    url: "/t/composer-loses-draft-when-switching-categories/1",
                  },
                  solved_by_users: [],
                },
              ],
            },
          },
        });
      });

      const renderer = adminReportRelatedItemsRenderer("accepted_solutions");
      this.set("tableSummaryComponent", renderer.tableSummaryComponent);

      await render(
        <template>
          {{component
            this.tableSummaryComponent
            date="2026-08-18"
            formattedValue="1"
          }}
        </template>
      );

      await click(".admin-report-table-summary");

      assert
        .dom(".admin-report-table-summary__message")
        .hasText(
          "Couldn't load the summary.",
          "shows the failed request state"
        );

      await click(".admin-report-table-summary");
      await click(".admin-report-table-summary");

      assert.strictEqual(requestCount, 2, "retries when the menu reopens");
      assert
        .dom(".solved-admin-report-table-summary__topic-link")
        .hasText(
          "Composer loses draft when switching categories",
          "shows the retried response"
        );
    });
  }
);
