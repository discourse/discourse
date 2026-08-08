import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AiRegenSummariesButtons from "discourse/plugins/discourse-ai/discourse/components/ai-regen-summaries-buttons";

class ToastsStub extends Service {
  messages = [];

  success({ data }) {
    this.messages.push(data.message);
  }

  error() {}
}

module("Integration | Component | AiRegenSummariesButtons", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.unregister("service:toasts");
    this.owner.register("service:toasts", ToastsStub);
    this.currentUser.can_request_gists = true;
    this.topicIds = [1];

    pretender.put("/discourse-ai/summarization/regen_gist", () =>
      response({ success: "OK" })
    );
    pretender.put("/discourse-ai/summarization/regen_summary", () =>
      response({ success: "OK" })
    );
  });

  test("reports regeneration as in progress after jobs are queued", async function (assert) {
    await render(
      <template>
        <AiRegenSummariesButtons @topicIds={{this.topicIds}} />
      </template>
    );

    await click(".ai-regen-gists-btn");
    await click(".ai-regen-summaries-btn");

    const toasts = this.owner.lookup("service:toasts");
    assert.deepEqual(
      toasts.messages,
      ["Regenerating short summaries…", "Regenerating topic summaries…"],
      "the toasts describe queued asynchronous work"
    );
  });
});
