import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("AI Bot - Sidebar community link", function (needs) {
  needs.user({
    ai_enabled_chat_bots: [
      {
        id: 1,
        model_name: "gpt-4",
        is_persona: false,
      },
    ],
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
      .dom(".sidebar-section-link[data-link-name='ai-bot'] .d-icon-robot")
      .exists("AI bot link has robot icon");

    assert
      .dom(".sidebar-section-link[data-link-name='ai-bot']")
      .hasText("AI bot", "AI bot link has correct text");
  });
});

acceptance("AI Bot - Sidebar community link - disabled", function (needs) {
  needs.user({
    ai_enabled_chat_bots: [
      {
        id: 1,
        model_name: "gpt-4",
        is_persona: false,
      },
    ],
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

acceptance("AI Bot - Sidebar community link - no bots", function (needs) {
  needs.user({
    ai_enabled_chat_bots: [],
  });

  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: true,
    ai_bot_add_to_community_section: true,
  });

  test("does not display AI bot link when no bots are available", async function (assert) {
    await visit("/");

    assert
      .dom(".sidebar-section-link[data-link-name='ai-bot']")
      .doesNotExist("AI bot link is not displayed when no bots are available");
  });
});

acceptance(
  "AI Bot - Sidebar community link - persona without default LLM",
  function (needs) {
    needs.user({
      ai_enabled_chat_bots: [
        {
          id: 1,
          model_name: "custom-persona",
          is_persona: true,
          has_default_llm: false,
        },
      ],
    });

    needs.settings({
      discourse_ai_enabled: true,
      ai_bot_enabled: true,
      ai_bot_add_to_community_section: true,
    });

    test("does not display AI bot link when persona has no default LLM", async function (assert) {
      await visit("/");

      assert
        .dom(".sidebar-section-link[data-link-name='ai-bot']")
        .doesNotExist(
          "AI bot link is not displayed when persona lacks default LLM"
        );
    });
  }
);

acceptance(
  "AI Bot - Sidebar community link - persona with default LLM",
  function (needs) {
    needs.user({
      ai_enabled_chat_bots: [
        {
          id: 1,
          model_name: "custom-persona",
          is_persona: true,
          has_default_llm: true,
        },
      ],
    });

    needs.settings({
      discourse_ai_enabled: true,
      ai_bot_enabled: true,
      ai_bot_add_to_community_section: true,
    });

    test("displays AI bot link when persona has default LLM", async function (assert) {
      await visit("/");

      assert
        .dom(".sidebar-section-link[data-link-name='ai-bot']")
        .exists("AI bot link is displayed when persona has default LLM");
    });
  }
);
