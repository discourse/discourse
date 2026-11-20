import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Service | ai-bot-conversations-hidden-submit", function (hooks) {
  setupTest(hooks);

  test("submits independent agent and model IDs with the agent recipient", async function (assert) {
    const owner = getOwner(this);
    const service = owner.lookup("service:ai-bot-conversations-hidden-submit");
    const siteSettings = owner.lookup("service:site-settings");
    siteSettings.min_personal_message_post_length = 5;

    let submittedBody;
    pretender.post("/discourse-ai/ai-bot/conversations.json", (request) => {
      submittedBody = new URLSearchParams(request.requestBody);
      return response({
        topic_id: 42,
        topic_slug: "agent-conversation",
        post_url: "/t/agent-conversation/42/1",
      });
    });

    service.router.transitionTo = () => {};
    service.inputValue = "Please answer this question";
    service.targetUsername = "forum_helper";
    service.agentId = -7;
    service.llmModelId = 99;

    await service.submitToBot({ uploads: [], inProgressUploadsCount: 0 });

    assert.strictEqual(submittedBody.get("target_username"), "forum_helper");
    assert.strictEqual(submittedBody.get("ai_agent_id"), "-7");
    assert.strictEqual(submittedBody.get("ai_llm_model_id"), "99");
  });
});
