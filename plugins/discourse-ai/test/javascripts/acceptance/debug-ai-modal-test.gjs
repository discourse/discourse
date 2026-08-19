import { getOwner } from "@ember/owner";
import { click, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";
import DebugAiModal from "discourse/plugins/discourse-ai/discourse/components/modal/debug-ai-modal";

const MODEL = { id: 42 };

const RAW_RESPONSE =
  'data: {"choices":[{"delta":{"content":"Decoded response"}}]}\n\ndata: [DONE]\n\n';

function auditLog(timeToFirstToken, duration = 22_300, overrides = {}) {
  return {
    id: 1,
    request_tokens: 10,
    response_tokens: 5,
    raw_request_payload: "{}",
    raw_response_payload: RAW_RESPONSE,
    decoded_response: "Decoded response",
    has_decoded_response: true,
    duration_msecs: duration,
    time_to_first_token_msecs: timeToFirstToken,
    ...overrides,
  };
}

acceptance("AI debug modal", function (needs) {
  let timeToFirstToken;
  let initialOverrides;

  needs.user();
  needs.hooks.beforeEach(() => {
    timeToFirstToken = undefined;
    initialOverrides = undefined;
  });
  needs.pretender((server, helper) => {
    server.get("/discourse-ai/ai-bot/post/42/show-debug-info.json", () =>
      helper.response(auditLog(timeToFirstToken, 22_300, initialOverrides))
    );
    server.get("/discourse-ai/ai-bot/show-debug-info/2.json", () =>
      helper.response(
        auditLog(timeToFirstToken, 22_300, {
          id: 2,
          decoded_response: "Next decoded response",
        })
      )
    );
  });

  test("it displays total duration and time to first token", async function (assert) {
    timeToFirstToken = 10_300;
    await visit("/");

    getOwner(this).lookup("service:modal").show(DebugAiModal, { model: MODEL });
    await settled();

    assert
      .dom(".ai-debug-modal__duration")
      .hasText(
        "Duration: 22.3 secs (first token: 10.3 secs)",
        "it presents the two latency measurements together"
      );
  });

  test("it displays decoded responses and switches representations", async function (assert) {
    await visit("/");
    getOwner(this).lookup("service:modal").show(DebugAiModal, { model: MODEL });
    await settled();

    await click(".ai-debug-modal__nav li:nth-child(2) a");

    assert
      .dom(".ai-decoded-transcript__text")
      .hasText("Decoded response", "the decoded response is shown first");
    assert
      .dom(".d-modal__footer .ai-debug-modal__response-toggle")
      .hasText(
        i18n("discourse_ai.view_raw"),
        "the raw response can be selected from the footer"
      );
    assert
      .dom(".d-modal__footer .ai-debug-modal__copy")
      .hasText(
        i18n("discourse_ai.ai_bot.debug_ai_modal.copy_response"),
        "the response copy action stays in the modal footer"
      );
    assert
      .dom(".d-modal__body .ai-debug-modal__copy")
      .doesNotExist("the copy action is outside the scrolling modal body");

    await click(".ai-debug-modal__response-toggle");

    assert
      .dom(".ai-payload-viewer__content")
      .hasText(RAW_RESPONSE, "the exact raw response is shown");
    assert
      .dom(".ai-debug-modal__response-toggle")
      .hasText(
        i18n("discourse_ai.view_decoded"),
        "the decoded response can be restored"
      );
    assert
      .dom(".ai-debug-modal__copy")
      .hasText(
        i18n("discourse_ai.ai_bot.debug_ai_modal.copy_response"),
        "the response copy action is identified"
      );

    await click(".ai-debug-modal__response-toggle");
    assert
      .dom(".ai-decoded-transcript__text")
      .hasText("Decoded response", "the decoded response is restored");
    assert
      .dom("#ai-debug-modal-copy-source")
      .doesNotExist("copying does not depend on a fixed DOM source");

    const writeText = sinon.stub().resolves();
    sinon.stub(window.navigator, "clipboard").get(() => ({ writeText }));

    assert
      .dom(".ai-debug-modal__copy-actions .sr-only[aria-live='polite']")
      .exists("copy feedback can be announced");

    await click(".ai-debug-modal__copy");

    assert.true(
      writeText.calledWithExactly("Decoded response"),
      "the active decoded payload is copied"
    );
  });

  test("it presents thinking and tool activity as structured details", async function (assert) {
    initialOverrides = {
      decoded_response: JSON.stringify({
        thinking: "Check the documentation",
        tool_calls: [
          { id: "call-1", name: "search", arguments: { query: "decoder" } },
        ],
        tool_results: [
          { call_id: "call-1", type: "search_result", result: "Found it" },
        ],
        response: "Done",
      }),
    };
    await visit("/");
    getOwner(this).lookup("service:modal").show(DebugAiModal, { model: MODEL });
    await settled();

    await click(".ai-debug-modal__nav li:nth-child(2) a");

    assert
      .dom(".ai-decoded-transcript__thinking")
      .includesText(
        "Check the documentation",
        "thinking is clearly identified"
      );
    assert
      .dom(".ai-decoded-transcript__item-heading")
      .includesText("search", "tool calls are clearly identified");
    assert
      .dom(".ai-decoded-transcript__code")
      .includesText('"query": "decoder"', "tool arguments are readable");
    assert
      .dom(".ai-decoded-transcript__section.--tool-results")
      .includesText("Found it", "tool results are clearly identified");
    assert
      .dom(".ai-decoded-transcript__section.--response")
      .includesText("Done", "the final response is clearly identified");
  });

  test("it omits the switch for raw fallback responses", async function (assert) {
    initialOverrides = {
      raw_response_payload: "upstream error",
      decoded_response: "upstream error",
      has_decoded_response: false,
    };
    await visit("/");
    getOwner(this).lookup("service:modal").show(DebugAiModal, { model: MODEL });
    await settled();

    await click(".ai-debug-modal__nav li:nth-child(2) a");

    assert
      .dom(".ai-debug-modal__response-toggle")
      .doesNotExist("no representation switch is shown");
    assert
      .dom(".ai-debug-modal__copy")
      .hasText(
        i18n("discourse_ai.ai_bot.debug_ai_modal.copy_response"),
        "the existing copy action remains unchanged"
      );
  });

  test("it resets to decoded when navigating between logs", async function (assert) {
    initialOverrides = { next_log_id: 2 };
    await visit("/");
    getOwner(this).lookup("service:modal").show(DebugAiModal, { model: MODEL });
    await settled();

    await click(".ai-debug-modal__nav li:nth-child(2) a");
    await click(".ai-debug-modal__response-toggle");
    await click(".ai-debug-modal__next");

    assert
      .dom(".ai-decoded-transcript__text")
      .hasText("Next decoded response", "navigation restores the decoded view");
    assert
      .dom(".ai-debug-modal__copy")
      .hasText(
        i18n("discourse_ai.ai_bot.debug_ai_modal.copy_response"),
        "the response copy label is restored"
      );
  });

  test("it identifies unavailable historical timing", async function (assert) {
    timeToFirstToken = null;
    await visit("/");

    getOwner(this).lookup("service:modal").show(DebugAiModal, { model: MODEL });
    await settled();

    assert
      .dom(".ai-debug-modal__duration")
      .hasText(
        "Duration: 22.3 secs (first token: —)",
        "it preserves total duration for historical logs"
      );
  });
});
