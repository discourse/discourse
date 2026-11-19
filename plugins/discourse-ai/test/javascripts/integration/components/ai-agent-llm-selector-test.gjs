import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AiAgentLlmSelector from "discourse/plugins/discourse-ai/discourse/components/ai-agent-llm-selector";

module("Integration | Component | AiAgentLlmSelector", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser = this.owner.lookup("service:current-user");
    this.currentUser.admin = false;
    this.keyValueStore = this.owner.lookup("service:key-value-store");
    this.keyValueStore.remove("ai_agent_selector_id");
    this.keyValueStore.remove("ai_llm_selector_id");
    this.keyValueStore.remove("ai_llm_selector_model_id");

    this.currentUser.ai_enabled_agents = [
      {
        id: -1,
        name: "Forum helper",
        username: "forum_helper",
        allow_personal_messages: true,
        default_llm_id: 1,
        has_default_llm: true,
        force_default_llm: false,
      },
    ];
    this.currentUser.ai_available_llm_models = [
      {
        id: 1,
        display_name: "Alpha",
        legacy_user_id: -100,
      },
      {
        id: 2,
        display_name: "Beta",
        legacy_user_id: -101,
      },
    ];

    this.agentId = null;
    this.llmId = null;
    this.targetRecipient = null;
    this.setAgentId = (id) => (this.agentId = id);
    this.setLlmId = (id) => (this.llmId = id);
    this.setTargetRecipient = (username) => (this.targetRecipient = username);
  });

  test("switching agents updates the dropdown label with the same model", async function (assert) {
    this.currentUser.admin = true;
    this.currentUser.ai_enabled_agents.push({
      ...this.currentUser.ai_enabled_agents[0],
      id: -2,
      name: "Focused helper",
      username: "focused_helper",
    });

    await render(
      <template>
        <AiAgentLlmSelector
          @setAgentId={{this.setAgentId}}
          @setLlmId={{this.setLlmId}}
          @setTargetRecipient={{this.setTargetRecipient}}
          @showMenuHeadings={{true}}
        />
      </template>
    );

    const agentSelector = selectKit(".agent-llm-selector__agent-dropdown");
    assert.strictEqual(
      agentSelector.header().label(),
      "Forum helper",
      "displays the initial agent"
    );
    assert
      .dom(".agent-llm-selector__menu-heading")
      .doesNotExist("hides menu headings when the menus are closed");

    await agentSelector.expand();
    assert
      .dom(
        ".agent-llm-selector__agent-dropdown .agent-llm-selector__menu-heading"
      )
      .hasText("Agent", "shows the Agent heading inside the open menu");
    assert
      .dom(".agent-llm-selector__menu-settings")
      .hasAttribute(
        "href",
        "/admin/plugins/discourse-ai/ai-agents",
        "lets admins open agent settings"
      );
    await agentSelector.selectRowByValue(-2);

    assert.strictEqual(
      agentSelector.header().label(),
      "Focused helper",
      "displays the newly selected agent immediately"
    );
    assert.strictEqual(this.llmId, 1, "keeps the selected model");
  });

  test("switching models preserves the agent recipient", async function (assert) {
    await render(
      <template>
        <AiAgentLlmSelector
          @setAgentId={{this.setAgentId}}
          @setLlmId={{this.setLlmId}}
          @setTargetRecipient={{this.setTargetRecipient}}
          @showMenuHeadings={{true}}
        />
      </template>
    );

    const llmSelector = selectKit(".agent-llm-selector__llm-dropdown");
    assert.strictEqual(this.agentId, -1, "selects the available agent");
    assert.strictEqual(this.llmId, 1, "selects the first available model");
    assert.strictEqual(
      this.targetRecipient,
      "forum_helper",
      "addresses the agent"
    );

    await llmSelector.expand();
    assert
      .dom(
        ".agent-llm-selector__llm-dropdown .agent-llm-selector__menu-heading"
      )
      .hasText(
        "Language model",
        "shows the Language model heading inside the open menu"
      );
    assert
      .dom(".agent-llm-selector__menu-settings")
      .doesNotExist("hides model settings from non-admins");
    await llmSelector.selectRowByValue(2);

    assert.strictEqual(this.llmId, 2, "changes the model by LLM ID");
    assert.strictEqual(
      this.targetRecipient,
      "forum_helper",
      "does not replace the recipient with a model user"
    );
    assert.strictEqual(
      this.keyValueStore.getItem("ai_llm_selector_model_id"),
      "2",
      "stores the model ID under the versioned key"
    );
  });

  test("translates a stored legacy model-user ID once", async function (assert) {
    this.keyValueStore.setItem("ai_llm_selector_id", -101);

    await render(
      <template>
        <AiAgentLlmSelector
          @setAgentId={{this.setAgentId}}
          @setLlmId={{this.setLlmId}}
          @setTargetRecipient={{this.setTargetRecipient}}
          @showMenuHeadings={{true}}
        />
      </template>
    );

    assert.strictEqual(this.llmId, 2, "maps the old user ID to its model ID");
    assert.strictEqual(
      this.keyValueStore.getItem("ai_llm_selector_model_id"),
      "2",
      "persists the translated model ID"
    );
    assert.strictEqual(this.targetRecipient, "forum_helper");
  });

  test("does not replace an unavailable explicit agent", async function (assert) {
    await render(
      <template>
        <AiAgentLlmSelector
          @agentId={{-999}}
          @setAgentId={{this.setAgentId}}
          @setLlmId={{this.setLlmId}}
          @setTargetRecipient={{this.setTargetRecipient}}
          @showMenuHeadings={{true}}
        />
      </template>
    );

    assert.strictEqual(
      this.agentId,
      null,
      "keeps the explicit selection unresolved"
    );
    assert.strictEqual(
      this.targetRecipient,
      "",
      "does not address another agent"
    );
    assert
      .dom(".agent-llm-selector__agent-dropdown")
      .exists("offers the available replacement explicitly");
  });

  test("does not replace an unavailable explicit model", async function (assert) {
    this.currentUser.ai_available_llm_models = [
      this.currentUser.ai_available_llm_models[0],
    ];

    await render(
      <template>
        <AiAgentLlmSelector
          @agentId={{-1}}
          @llmModelId={{999}}
          @setAgentId={{this.setAgentId}}
          @setLlmId={{this.setLlmId}}
          @setTargetRecipient={{this.setTargetRecipient}}
          @showMenuHeadings={{true}}
        />
      </template>
    );

    assert.strictEqual(
      this.llmId,
      999,
      "preserves the explicit model for visible server-side rejection"
    );
    assert
      .dom(".agent-llm-selector__llm-dropdown")
      .exists("offers a recoverable model selection");
  });

  test("does not replace an unavailable explicit legacy model name", async function (assert) {
    this.keyValueStore.setItem("ai_llm_selector_model_id", 2);

    await render(
      <template>
        <AiAgentLlmSelector
          @agentId={{-1}}
          @llmName="Retired model"
          @setAgentId={{this.setAgentId}}
          @setLlmId={{this.setLlmId}}
          @setTargetRecipient={{this.setTargetRecipient}}
          @showMenuHeadings={{true}}
        />
      </template>
    );

    assert.strictEqual(
      this.llmId,
      "Retired model",
      "preserves the explicit legacy name for visible rejection"
    );
    assert
      .dom(".agent-llm-selector__llm-dropdown")
      .exists("requires a recoverable replacement selection");
  });

  test("a forced agent uses its default model and hides model choices", async function (assert) {
    this.currentUser.ai_enabled_agents[0].force_default_llm = true;
    this.currentUser.ai_enabled_agents[0].default_llm_id = 2;

    await render(
      <template>
        <AiAgentLlmSelector
          @setAgentId={{this.setAgentId}}
          @setLlmId={{this.setLlmId}}
          @setTargetRecipient={{this.setTargetRecipient}}
          @showMenuHeadings={{true}}
        />
      </template>
    );

    assert.strictEqual(this.llmId, 2);
    assert.dom(".agent-llm-selector__llm-dropdown").doesNotExist();
    assert.strictEqual(this.targetRecipient, "forum_helper");
  });

  test("switching through a forced agent preserves the model preference", async function (assert) {
    this.currentUser.ai_enabled_agents.push({
      id: -2,
      name: "Focused helper",
      username: "focused_helper",
      allow_personal_messages: true,
      default_llm_id: 2,
      has_default_llm: true,
      force_default_llm: true,
    });
    this.keyValueStore.setItem("ai_llm_selector_model_id", 1);

    await render(
      <template>
        <AiAgentLlmSelector
          @setAgentId={{this.setAgentId}}
          @setLlmId={{this.setLlmId}}
          @setTargetRecipient={{this.setTargetRecipient}}
          @showMenuHeadings={{true}}
        />
      </template>
    );

    const agentSelector = selectKit(".agent-llm-selector__agent-dropdown");
    await agentSelector.expand();
    await agentSelector.selectRowByValue(-2);

    assert.strictEqual(this.llmId, 2, "uses the forced model");
    assert.strictEqual(
      this.keyValueStore.getItem("ai_llm_selector_model_id"),
      "1",
      "does not replace the model preference"
    );

    await agentSelector.expand();
    await agentSelector.selectRowByValue(-1);

    assert.strictEqual(this.llmId, 1, "restores the preferred model");
    assert.dom(".agent-llm-selector__llm-dropdown").exists();
  });
});
