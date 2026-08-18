import { getOwner } from "@ember/owner";
import { settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import DebugAiModal from "discourse/plugins/discourse-ai/discourse/components/modal/debug-ai-modal";

const MODEL = { id: 42 };

function auditLog(timeToFirstToken, duration = 22_300) {
  return {
    id: 1,
    request_tokens: 10,
    response_tokens: 5,
    raw_request_payload: "{}",
    raw_response_payload: "response",
    duration_msecs: duration,
    time_to_first_token_msecs: timeToFirstToken,
  };
}

acceptance("AI debug modal", function (needs) {
  let timeToFirstToken;

  needs.user();
  needs.pretender((server, helper) => {
    server.get("/discourse-ai/ai-bot/post/42/show-debug-info.json", () =>
      helper.response(auditLog(timeToFirstToken))
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
