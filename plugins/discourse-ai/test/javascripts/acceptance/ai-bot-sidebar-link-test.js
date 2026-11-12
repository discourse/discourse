import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

const AVAILABLE_AGENT = {
  id: -1,
  username: "forum_helper",
  allow_personal_messages: true,
  has_default_llm: true,
};

const AVAILABLE_MODEL = { id: 1, model_name: "gpt-4", display_name: "GPT-4" };

acceptance("AI Bot - Sidebar community link", function (needs) {
  needs.user({
    ai_enabled_agents: [AVAILABLE_AGENT],
    ai_available_llm_models: [AVAILABLE_MODEL],
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: true,
    ai_bot_add_to_community_section: true,
  });

  test("displays AI bot link in community section when enabled", async function (assert) {
    await visit("/");

    assert
      .dom(".sidebar-section-link[data-link-name='ai-bot']")
      .exists("AI bot link is displayed in the sidebar");

    assert
      .dom(".sidebar-section-link[data-link-name='ai-bot'] .d-icon-discobot")
      .exists("AI bot link has discobot icon");

    assert
      .dom(".sidebar-section-link[data-link-name='ai-bot']")
      .hasText("AI bot", "AI bot link has correct text");
  });
});

acceptance("AI Bot - Sidebar community link - disabled", function (needs) {
  needs.user({
    ai_enabled_agents: [AVAILABLE_AGENT],
    ai_available_llm_models: [AVAILABLE_MODEL],
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: true,
    ai_bot_add_to_community_section: false,
  });

  test("does not display AI bot link when setting is disabled", async function (assert) {
    await visit("/");

    assert
      .dom(".sidebar-section-link[data-link-name='ai-bot']")
      .doesNotExist("AI bot link is not displayed when setting is disabled");
  });
});

acceptance("AI Bot - Sidebar community link - no agents", function (needs) {
  needs.user({
    ai_enabled_agents: [],
    ai_available_llm_models: [AVAILABLE_MODEL],
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: true,
    ai_bot_add_to_community_section: true,
  });

  test("does not display AI bot link when no agents are available", async function (assert) {
    await visit("/");

    assert
      .dom(".sidebar-section-link[data-link-name='ai-bot']")
      .doesNotExist(
        "AI bot link is not displayed when no agents are available"
      );
  });
});

acceptance(
  "AI Bot - Sidebar community link - agent without a model",
  function (needs) {
    needs.user({
      ai_enabled_agents: [
        {
          ...AVAILABLE_AGENT,
          has_default_llm: false,
        },
      ],
      ai_available_llm_models: [],
    });

    needs.settings({
      discourse_ai_enabled: true,
      ai_bot_enabled: true,
      ai_bot_add_to_community_section: true,
    });

    test("does not display AI bot link when agent has no model", async function (assert) {
      await visit("/");

      assert
        .dom(".sidebar-section-link[data-link-name='ai-bot']")
        .doesNotExist("AI bot link is not displayed when agent lacks a model");
    });
  }
);

acceptance(
  "AI Bot - Sidebar community link - agent with default LLM",
  function (needs) {
    needs.user({
      ai_enabled_agents: [AVAILABLE_AGENT],
      ai_available_llm_models: [],
    });

    needs.settings({
      discourse_ai_enabled: true,
      ai_bot_enabled: true,
      ai_bot_add_to_community_section: true,
    });

    test("displays AI bot link when agent has default LLM", async function (assert) {
      await visit("/");

      assert
        .dom(".sidebar-section-link[data-link-name='ai-bot']")
        .exists("AI bot link is displayed when agent has default LLM");
    });
  }
);
