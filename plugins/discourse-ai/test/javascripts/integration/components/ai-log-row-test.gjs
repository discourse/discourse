import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiLogRow from "discourse/plugins/discourse-ai/discourse/components/ai-log-row";

module("Integration | Component | AiLogRow", function (hooks) {
  setupRenderingTest(hooks);

  test("renders statusless positive-token calls as successful", async function (assert) {
    this.log = {
      id: 43,
      created_at: "2026-08-17T12:00:00Z",
      response_status: null,
      response_tokens: 1,
    };

    await render(
      <template>
        <table><tbody><AiLogRow @log={{this.log}} /></tbody></table>
      </template>
    );

    assert
      .dom(".ai-logs__status-icon.d-icon-circle-check")
      .hasAttribute(
        "aria-label",
        "Successful",
        "success uses a labelled check icon"
      );
  });

  test("renders operational metadata and opens details", async function (assert) {
    this.log = {
      id: 42,
      created_at: "2026-08-17T12:00:00Z",
      response_status: 500,
      response_tokens: 3_000,
      request_tokens: 12_000,
      duration_msecs: 1_400,
      has_retries: true,
      feature_name: "summarize",
      model_name: "Test model",
      username: "user1",
      avatar_template: "/letter_avatar_proxy/v4/letter/u/13edae/{size}.png",
      topic_id: 10,
      post_id: 11,
    };
    this.openedId = null;
    this.open = (id) => (this.openedId = id);

    await render(
      <template>
        <table><tbody><AiLogRow
              @log={{this.log}}
              @onOpen={{this.open}}
            /></tbody></table>
      </template>
    );

    assert
      .dom(".ai-logs__status-icon.d-icon-circle-xmark")
      .hasAttribute(
        "aria-label",
        "Failed",
        "failure uses a labelled xmark icon"
      );
    assert.dom(".ai-logs__flag").exists({ count: 1 }, "retry uses an icon");
    assert
      .dom('.ai-logs__flag[aria-label="Retried"]')
      .exists("retry state is available to assistive technology");
    assert
      .dom(".ai-logs__row .fk-d-tooltip__trigger")
      .exists({ count: 2 }, "status and retry icons surface tooltips");
    assert.dom(".ai-logs__id").doesNotExist("log ID is omitted");
    assert.dom(".ai-logs__feature").hasText("summarize");
    assert.dom(".ai-logs__model").hasText("Test model");
    assert.dom(".ai-logs__user").hasAttribute("href", "/u/user1");
    assert.dom(".ai-logs__duration-value").hasText("1.4 s");
    assert
      .dom('.ai-logs__col-context a[href="/t/10"]')
      .hasText("Topic 10", "topic is linked");
    assert
      .dom('.ai-logs__col-context a[href="/p/11"]')
      .hasText("Post 11", "post is linked");
    assert
      .dom(".ai-logs__token-summary")
      .includesText("12k → 3k", "tokens are compact and directional");
    assert
      .dom(".ai-logs__token-summary .sr-only")
      .hasText(
        "12,000 input tokens and 3,000 output tokens",
        "assistive text retains exact token counts"
      );
    assert
      .dom(".ai-logs__row .btn .d-icon-far-file-lines")
      .exists("details is an icon-only button");
    assert
      .dom(".ai-logs__row .btn")
      .hasAttribute(
        "aria-label",
        "Details",
        "details icon has an accessible name"
      );
    assert
      .dom(".ai-logs__row .btn")
      .hasAttribute("title", "Details", "details icon has a tooltip");

    await click(".ai-logs__row .btn");
    assert.strictEqual(this.openedId, 42, "details open for the selected log");
  });
});
