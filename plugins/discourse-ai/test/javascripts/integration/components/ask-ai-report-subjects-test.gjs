import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AskAiReportSubjects from "discourse/plugins/discourse-ai/admin/components/dashboard/ask-ai-report-subjects";

const endpoint = "/admin/plugins/discourse-ai/ask-ai-reports/1/subjects";

module("Integration | Component | AskAiReportSubjects", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.report = {
      id: 1,
      topic_url: "/t/report/123",
      reported_ask_count: 20,
      total_ask_count: 100,
      subjects: [1, 2, 3, 4].map((id) => ({
        id,
        name: `Subject ${id}`,
        description: `Description ${id}`,
        ask_count: 5,
      })),
    };
  });

  test("shows the saved summary as plain text without requiring a PM", async function (assert) {
    this.report.summary = "<img src=x> Users ask about 猫 and settings.";
    this.report.topic_url = null;
    await render(
      <template><AskAiReportSubjects @report={{this.report}} /></template>
    );
    assert.dom(".ask-ai-report-subjects__summary").hasText(this.report.summary);
    assert.dom(".ask-ai-report-subjects__summary img").doesNotExist();
    assert.dom(".ask-ai-report-subjects__report-link").doesNotExist();
  });

  test("starts with three collapsed subjects and loads questions only when opened", async function (assert) {
    let requests = 0;
    pretender.get(`${endpoint}/1/asks`, (request) => {
      requests++;
      return response({
        asks: [
          {
            id: request.queryParams.before ? 1 : 2,
            query: request.queryParams.before
              ? "Earlier question"
              : "<img src=x> 猫",
            asked_at: "2026-09-16T12:00:00Z",
          },
        ],
        next_before: request.queryParams.before ? null : 2,
      });
    });
    await render(
      <template><AskAiReportSubjects @report={{this.report}} /></template>
    );
    assert
      .dom(".ask-ai-report-subject")
      .exists({ count: 3 }, "shows the leading subjects");
    assert
      .dom('.ask-ai-report-subject__toggle[aria-expanded="false"]')
      .exists({ count: 3 }, "starts collapsed");
    assert.strictEqual(requests, 0, "does not fetch hidden questions");
    assert
      .dom(".ask-ai-report-subjects__actions a")
      .hasAttribute("href", "/t/report/123")
      .hasAttribute("target", "_blank")
      .hasAttribute("rel", "noopener noreferrer")
      .hasAttribute("aria-label", "View full report (opens in a new tab)")
      .hasText(
        "View full report",
        "groups the report link with the subject toggle"
      );
    assert
      .dom(".ask-ai-report-subjects__footer")
      .includesText("20 of 100", "shows coverage");
    await click(".ask-ai-report-subject__toggle");
    assert
      .dom('.ask-ai-report-subject__toggle[aria-expanded="true"]')
      .exists({ count: 1 }, "expands the selected subject");
    assert
      .dom(".ask-ai-report-questions")
      .includesText("<img src=x> 猫", "shows the original query");
    assert
      .dom(".ask-ai-report-questions img")
      .doesNotExist("escapes query markup");
    await click(".ask-ai-report-questions__more");
    assert
      .dom(".ask-ai-report-questions li")
      .exists({ count: 2 }, "appends the next page");
    assert
      .dom(".ask-ai-report-questions__more")
      .doesNotExist("stops paging at the last question");
    await click(".ask-ai-report-subjects__show-all");
    assert
      .dom(".ask-ai-report-subject")
      .exists({ count: 4 }, "shows all subjects");
    assert.strictEqual(
      requests,
      2,
      "showing more subjects does not fetch their questions"
    );
    await click(".ask-ai-report-subjects__show-all");
    assert
      .dom(".ask-ai-report-subject")
      .exists({ count: 3 }, "returns to the compact view");
  });

  test("shows three example questions before revealing more", async function (assert) {
    let requests = 0;
    pretender.get(`${endpoint}/1/asks`, (request) => {
      requests++;
      const ids = request.queryParams.before ? [2, 1] : [7, 6, 5, 4, 3];
      return response({
        asks: ids.map((id) => ({
          id,
          query: `Question ${id}`,
          asked_at: "2026-09-16T12:00:00Z",
        })),
        next_before: request.queryParams.before ? null : 3,
      });
    });
    await render(
      <template><AskAiReportSubjects @report={{this.report}} /></template>
    );
    await click(".ask-ai-report-subject__toggle");
    assert.dom(".ask-ai-report-questions li").exists({ count: 3 });
    assert.dom(".ask-ai-report-questions").doesNotIncludeText("Question 4");
    await click(".ask-ai-report-questions__more");
    assert.dom(".ask-ai-report-questions li").exists({ count: 5 });
    assert.strictEqual(
      requests,
      1,
      "reveals loaded questions before fetching more"
    );
    await click(".ask-ai-report-questions__more");
    assert.dom(".ask-ai-report-questions li").exists({ count: 7 });
    assert.strictEqual(requests, 2);
    assert.dom(".ask-ai-report-questions__more").doesNotExist();
  });

  test("opens the stored answer and explains when answer text is unavailable", async function (assert) {
    pretender.get(`${endpoint}/1/asks`, () =>
      response({
        asks: [
          { id: 7, query: "Question 猫", asked_at: "2026-09-16T12:00:00Z" },
        ],
        next_before: null,
      })
    );
    let answer = "<img src=x> Stored answer 猫";
    pretender.get(`${endpoint}/1/asks/7`, () =>
      response({
        ask: {
          id: 7,
          query: "Question 猫",
          answer,
          ask_outcome: "answered",
          asked_at: "2026-09-16T12:00:00Z",
        },
      })
    );
    await render(
      <template>
        <ModalContainer /><AskAiReportSubjects @report={{this.report}} />
      </template>
    );
    await click(".ask-ai-report-subject__toggle");
    await click(".ask-ai-report-questions__query");
    assert.dom(".ask-ai-report-answer__text", document).hasText(answer);
    assert
      .dom(".ask-ai-report-answer img", document)
      .doesNotExist("escapes stored answer markup");
    await click(".modal-close");
    answer = null;
    await click(".ask-ai-report-questions__query");
    assert
      .dom(".ask-ai-report-answer", document)
      .includesText("No answer text was stored for this ask.");
  });

  test("allows retry and explains when the original logs have been deleted", async function (assert) {
    this.report.subjects = this.report.subjects.slice(0, 1);
    this.report.topic_url = null;
    let fail = true;
    pretender.get(`${endpoint}/1/asks`, () =>
      fail ? [500, {}, "{}"] : response({ asks: [], next_before: null })
    );
    await render(
      <template><AskAiReportSubjects @report={{this.report}} /></template>
    );
    assert
      .dom(".ask-ai-report-subjects__show-all")
      .doesNotExist("a small report needs no show-all control");
    await click(".ask-ai-report-subject__toggle");
    assert
      .dom('[role="alert"]')
      .hasText("Questions could not be loaded.", "shows a request failure");
    fail = false;
    await click(".ask-ai-report-questions__retry");
    assert
      .dom(".ask-ai-report-questions")
      .includesText(
        "The original asks are no longer available.",
        "explains missing logs"
      );
    assert.dom('[role="alert"]').doesNotExist("clears the failure after retry");
    assert
      .dom(".ask-ai-report-subjects__actions a")
      .doesNotExist("omits an unavailable PM link");
  });
});
