import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";
import AiFeaturesChatbotAgents from "discourse/plugins/discourse-ai/discourse/components/ai-features-chatbot-agents";

function agent(overrides = {}) {
  return {
    id: 1,
    name: "Forum Helper",
    chatbot: true,
    personal_messages: true,
    topic_mentions: true,
    chat_direct_messages: false,
    chat_channel_mentions: false,
    allowed_groups: [{ id: 10, name: "trust_level_0" }],
    llm: null,
    ...overrides,
  };
}

function savedAttributes(request) {
  const params = new URLSearchParams(request.requestBody);
  return Object.fromEntries(
    [
      "allow_personal_messages",
      "allow_topic_mentions",
      "allow_chat_direct_messages",
      "allow_chat_channel_mentions",
    ].map((name) => [name, params.get(`ai_agent[${name}]`)])
  );
}

module("Integration | Component | AiFeaturesChatbotAgents", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  test("shows where each agent can be reached", async function (assert) {
    const agents = [
      agent(),
      agent({
        id: 2,
        name: "SQL Helper",
        chatbot: false,
        personal_messages: false,
        topic_mentions: false,
        llm: { id: 3, name: "Fast model" },
      }),
    ];

    await render(
      <template><AiFeaturesChatbotAgents @agents={{agents}} /></template>
    );

    assert
      .dom("[data-agent-id='1'] .ai-features-chatbot-agents__places")
      .includesText(
        `${i18n("discourse_ai.features.chatbot.places.personal_messages")} · ${i18n("discourse_ai.features.chatbot.places.topic_mentions")}`
      );
    assert
      .dom("[data-agent-id='1'] .ai-features-chatbot-agents__llm")
      .includesText(i18n("discourse_ai.features.chatbot.any_llm"));
    assert
      .dom("[data-agent-id='2'] .ai-features-chatbot-agents__places")
      .includesText(i18n("discourse_ai.features.chatbot.places.none"));
    assert
      .dom("[data-agent-id='2'] .ai-features-chatbot-agents__switch")
      .hasAria("checked", "false");
  });

  test("switching off only removes the places people can reach the agent", async function (assert) {
    let saved;
    let changed = false;
    pretender.put("/admin/plugins/discourse-ai/ai-agents/1.json", (request) => {
      saved = savedAttributes(request);
      return response({ ai_agent: {} });
    });
    const agents = [agent()];
    const onChange = () => (changed = true);

    await render(
      <template>
        <AiFeaturesChatbotAgents @agents={{agents}} @onChange={{onChange}} />
      </template>
    );
    await click("[data-agent-id='1'] .ai-features-chatbot-agents__switch");

    assert.deepEqual(saved, {
      allow_personal_messages: "false",
      allow_topic_mentions: "false",
      allow_chat_direct_messages: "false",
      allow_chat_channel_mentions: "false",
    });
    assert.true(changed, "reloads the features");
  });

  test("switching on offers the agent in personal messages", async function (assert) {
    let saved;
    pretender.put("/admin/plugins/discourse-ai/ai-agents/1.json", (request) => {
      saved = savedAttributes(request);
      return response({ ai_agent: {} });
    });
    const agents = [
      agent({
        chatbot: false,
        personal_messages: false,
        topic_mentions: false,
      }),
    ];

    await render(
      <template><AiFeaturesChatbotAgents @agents={{agents}} /></template>
    );
    await click("[data-agent-id='1'] .ai-features-chatbot-agents__switch");

    assert.deepEqual(saved, {
      allow_personal_messages: "true",
      allow_topic_mentions: "false",
      allow_chat_direct_messages: "false",
      allow_chat_channel_mentions: "false",
    });
  });

  test("enabling an agent preserves its configured places when its bot user is missing", async function (assert) {
    let saved;
    pretender.put("/admin/plugins/discourse-ai/ai-agents/1.json", (request) => {
      saved = savedAttributes(request);
      return response({ ai_agent: {} });
    });
    const agents = [
      agent({ chatbot: false, personal_messages: false, topic_mentions: true }),
    ];
    await render(
      <template><AiFeaturesChatbotAgents @agents={{agents}} /></template>
    );
    await click(".ai-features-chatbot-agents__switch");
    assert.deepEqual(
      saved,
      {
        allow_personal_messages: "false",
        allow_topic_mentions: "true",
        allow_chat_direct_messages: "false",
        allow_chat_channel_mentions: "false",
      },
      "keeps existing places rather than overwriting them with the default"
    );
  });

  test("disables the switches when asked", async function (assert) {
    const agents = [agent()];

    await render(
      <template>
        <AiFeaturesChatbotAgents @agents={{agents}} @disabled={{true}} />
      </template>
    );

    assert.dom(".ai-features-chatbot-agents__switch").isDisabled();
  });
});
