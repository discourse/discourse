import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  AGENT_SELECTOR_KEY,
  LLM_SELECTOR_KEY,
} from "discourse/plugins/discourse-ai/discourse/components/ai-agent-llm-selector";

export default class AiAskButton extends Component {
  @service aiBotConversationsHiddenSubmit;
  @service currentUser;
  @service keyValueStore;
  @service router;
  @service search;
  @service siteSettings;

  get shouldShow() {
    return (
      this.currentUser?.ai_enabled_chat_bots?.length > 0 &&
      this.siteSettings.ai_bot_add_to_header
    );
  }

  get hasText() {
    return (this.search.activeGlobalSearchTerm || "").trim().length > 0;
  }

  #resolveDefaults() {
    const enabledAgents = (this.currentUser.ai_enabled_agents || []).filter(
      (agent) => agent.allow_personal_messages
    );
    const hasLlmSelector = this.currentUser.ai_enabled_chat_bots?.some(
      (bot) => !bot.is_agent
    );
    const botOptions = hasLlmSelector
      ? enabledAgents
      : enabledAgents.filter((agent) => agent.username);

    if (!botOptions.length) {
      return null;
    }

    const storedAgentId = parseInt(
      this.keyValueStore.getItem(AGENT_SELECTOR_KEY),
      10
    );
    const selectedAgent =
      botOptions.find((bot) => bot.id === storedAgentId) || botOptions[0];
    const allowLLMSelector = hasLlmSelector && !selectedAgent.force_default_llm;

    let targetUsername = selectedAgent.username || "";
    if (allowLLMSelector) {
      const llmOptions = this.currentUser.ai_enabled_chat_bots.filter(
        (bot) => !bot.is_agent
      );
      const storedLlmId = parseInt(
        this.keyValueStore.getItem(LLM_SELECTOR_KEY),
        10
      );
      const selectedLlm =
        llmOptions.find((bot) => bot.id === storedLlmId) || llmOptions[0];
      if (selectedLlm) {
        targetUsername = selectedLlm.username;
      }
    }

    return { agentId: selectedAgent.id, targetUsername };
  }

  @action
  async handleClick() {
    if (!this.hasText) {
      this.router.transitionTo("/discourse-ai/ai-bot/conversations");
      return;
    }

    const inputValue = this.search.activeGlobalSearchTerm.trim();
    const defaults = this.#resolveDefaults();
    const minLength = this.siteSettings.min_personal_message_post_length;

    if (!defaults || inputValue.length < minLength) {
      this.router.transitionTo("/discourse-ai/ai-bot/conversations", {
        queryParams: { input: inputValue },
      });
      return;
    }

    this.aiBotConversationsHiddenSubmit.agentId = defaults.agentId;
    this.aiBotConversationsHiddenSubmit.targetUsername =
      defaults.targetUsername;
    this.aiBotConversationsHiddenSubmit.inputValue = inputValue;

    try {
      await this.aiBotConversationsHiddenSubmit.submitToBot({
        uploads: [],
        inProgressUploadsCount: 0,
      });
      this.search.activeGlobalSearchTerm = "";
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    {{#if this.shouldShow}}
      <DButton
        @icon="discobot"
        @label="discourse_ai.ai_bot.ask_button.label"
        @title="discourse_ai.ai_bot.ask_button.title"
        @action={{this.handleClick}}
        class={{concatClass
          "ai-ask-button"
          "btn-transparent"
          (if this.hasText "--active")
        }}
      />
    {{/if}}
  </template>
}
