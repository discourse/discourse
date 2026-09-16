import { click, fillIn, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AskAiReports from "discourse/plugins/discourse-ai/admin/components/dashboard/ask-ai-reports";

const endpoint = "/admin/plugins/discourse-ai/ask-ai-reports";

module("Integration | Component | AskAiReports", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(() => {
    pretender.get(endpoint, () =>
      response({
        reports: [],
        data_explorer_query_id: -47,
        recipient_groups: ["admins", "community_team"],
      })
    );
  });

  test("links to the selected report rather than the dashboard period", async function (assert) {
    pretender.get(endpoint, () =>
      response({
        data_explorer_query_id: -47,
        reports: [11, 10].map((id) => ({
          id,
          start_date: "2026-08-01",
          end_date: "2026-08-31",
          report_status: "completed",
          subjects: [],
        })),
      })
    );
    await render(
      <template>
        <AskAiReports @endDate="2026-09-16" @startDate="2026-09-01" />
      </template>
    );
    const link = ".ask-ai-reports .db-section__row-block-title a";
    assert
      .dom(link)
      .hasAttribute(
        "href",
        "/admin/plugins/discourse-data-explorer/queries/-47?params=" +
          encodeURIComponent(JSON.stringify({ report_id: 11 }))
      );
    await fillIn(".ask-ai-reports__period-picker select", "10");
    assert
      .dom(link)
      .hasAttribute(
        "href",
        "/admin/plugins/discourse-data-explorer/queries/-47?params=" +
          encodeURIComponent(JSON.stringify({ report_id: 10 }))
      );
  });

  test("links to max asks when report generation fails", async function (assert) {
    pretender.get(endpoint, () =>
      response({
        reports: [
          {
            id: 1,
            start_date: "2026-09-01",
            end_date: "2026-09-16",
            report_status: "failed",
            subjects: [],
          },
        ],
        recipient_groups: [],
      })
    );
    await render(
      <template>
        <AskAiReports
          @endDate="2026-09-16"
          @questions={{1}}
          @startDate="2026-09-01"
        />
      </template>
    );
    await waitFor(".ask-ai-reports__report-header");
    assert
      .dom(".ask-ai-reports__generate")
      .isNotDisabled("allows manual generation after failure or expiry");
    assert.dom(".ask-ai-reports .db-section__row-block-title a").doesNotExist();
    assert
      .dom(".ask-ai-reports__report-header")
      .includesText("If this keeps happening, consider reducing max asks.");
    assert
      .dom(".ask-ai-reports__report-header a")
      .hasText("max asks")
      .hasAttribute(
        "href",
        "/admin/site_settings/category/all_results?filter=ai_ask_ai_report_max_asks"
      )
      .hasAttribute("target", "_blank");
  });

  test("shows the first-report empty state", async function (assert) {
    await render(
      <template>
        <AskAiReports
          @endDate="2026-09-09"
          @questions={{12}}
          @startDate="2026-09-01"
        />
      </template>
    );
    assert
      .dom(".ask-ai-reports")
      .includesText("No reports generated yet.", "explains the empty history");
    assert.dom(".ask-ai-reports .db-section__row-block-title a").doesNotExist();
    assert
      .dom(".ask-ai-reports__period-picker")
      .doesNotExist("has no period selector before the first report");
    assert
      .dom(".ask-ai-reports__generate")
      .isNotDisabled("can generate the first report");
  });

  test("requests the selected period and recipient and shows its pending state", async function (assert) {
    pretender.post(endpoint, (request) => {
      const params = new URLSearchParams(request.requestBody);
      assert.strictEqual(
        params.get("start_date"),
        "2026-09-01",
        "sends the selected start"
      );
      assert.strictEqual(
        params.get("end_date"),
        "2026-09-09",
        "sends the selected end"
      );
      assert.strictEqual(
        params.get("send_to_groups"),
        "true",
        "sends the chosen recipient"
      );
      return response({
        report: {
          id: 1,
          start_date: "2026-09-01",
          end_date: "2026-09-09",
          report_status: "queued",
          reported_ask_count: 12,
          total_ask_count: 12,
          subjects: [],
        },
      });
    });

    await render(
      <template>
        <ModalContainer />
        <AskAiReports
          @endDate="2026-09-09"
          @questions={{12}}
          @startDate="2026-09-01"
        />
      </template>
    );
    assert
      .dom(
        ".ask-ai-reports .db-section__row-block-header .db-section__row-block-title"
      )
      .hasText(
        "What users are asking",
        "uses the shared dashboard block header"
      );
    assert.dom("form").doesNotExist("keeps the dashboard controls subtle");
    await waitFor(".ask-ai-reports__generate:not([disabled])");
    await click(".ask-ai-reports__generate");
    await waitFor('input[type="checkbox"]');
    assert
      .dom("body", document)
      .includesText("Sep 1, 2026", "confirms the selected period");
    assert
      .dom('input[type="checkbox"]')
      .isNotChecked("defaults to delivery to the requester");
    assert
      .dom(".d-modal", document)
      .doesNotIncludeText("New reports appear", "omits the delivery paragraph");
    assert
      .dom(".d-modal .fk-d-tooltip__trigger", document)
      .doesNotExist("uses one settings link instead of help indicators");
    assert
      .dom(".ask-ai-reports__settings", document)
      .hasAttribute(
        "href",
        "/admin/site_settings/category/all_results?filter=ai_ask_ai_report_",
        "opens report site settings"
      )
      .hasAttribute("target", "_blank")
      .hasAttribute("rel", "noopener noreferrer");
    assert
      .dom(".d-modal", document)
      .includesText(
        "Also send a PM to admins, community_team",
        "names the configured groups"
      );
    await click('input[type="checkbox"]');
    await click(".d-modal .btn-primary");
    assert
      .dom(".ask-ai-reports__report-header")
      .includesText("Queued", "shows the queued report");
    assert
      .dom(".ask-ai-reports__generate")
      .isDisabled("prevents another request while pending");
  });

  test("shows stored subjects and the PM for a previous period", async function (assert) {
    pretender.get(endpoint, () =>
      response({
        reports: [
          {
            id: 1,
            start_date: "2026-08-01",
            end_date: "2026-08-31",
            report_status: "completed",
            reported_ask_count: 200,
            total_ask_count: 300,
            subjects: [
              {
                id: 9,
                name: "Email",
                description: "Setting up email.",
                ask_count: 200,
              },
            ],
            topic_url: "/t/report/123",
          },
        ],
      })
    );
    await render(
      <template>
        <ModalContainer />
        <AskAiReports
          @endDate="2026-09-09"
          @questions={{0}}
          @startDate="2026-09-01"
        />
      </template>
    );
    assert
      .dom(".ask-ai-reports__report")
      .includesText("200 of 300", "shows sampling coverage");
    assert.dom(".ask-ai-reports__report").includesText("Subjects may overlap");
    assert
      .dom(".ask-ai-report-subject__toggle")
      .includesText("Email", "shows saved subject");
    assert
      .dom(".ask-ai-reports__report a")
      .hasAttribute("href", "/t/report/123", "links to the report PM");
    assert
      .dom(".ask-ai-reports")
      .doesNotIncludeText("Ready", "does not label completed reports");
    assert
      .dom(".db-section__row-block")
      .exists({ count: 1 }, "keeps reports in one section");
    assert
      .dom(".ask-ai-reports__report")
      .includesText(
        "Setting up email.",
        "shows the selected subject description"
      );
    assert
      .dom(".ask-ai-reports__generate")
      .isDisabled("does not request an empty period");
  });
});
