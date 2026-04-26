import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import { i18n } from "discourse-i18n";

const AGENT_SELECTOR_KEY = "ai_agent_selector_id";
const LLM_SELECTOR_KEY = "ai_llm_selector_id";

export default class AiAgentLlmSelector extends Component {
  @service currentUser;
  @service keyValueStore;

  @tracked llm;
  @tracked allowLLMSelector = true;

  constructor() {
    super(...arguments);

    if (this.botOptions?.length) {
      this.#loadStoredAgent();
      this.#loadStoredLlm();

      next(() => {
        this.resetTargetRecipients();
      });
    }
  }

  get composer() {
    return this.args?.outletArgs?.model;
  }

  get hasLlmSelector() {
    return (
      this.currentUser.ai_enabled_chat_bots?.some((bot) => !bot.is_agent) ||
      false
    );
  }

  get enabledAgents() {
    return this.currentUser.ai_enabled_agents || [];
  }

  get botOptions() {
    if (!this.enabledAgents) {
      return;
    }

    let enabledAgents = this.enabledAgents;
    enabledAgents = enabledAgents.filter(
      (agent) => agent.allow_personal_messages
    );

    if (!this.hasLlmSelector) {
      enabledAgents = enabledAgents.filter((agent) => agent.username);
    }

    return enabledAgents.map((agent) => {
      return {
        id: agent.id,
        name: agent.name,
        description: agent.description,
      };
    });
  }

  get filterable() {
    return this.botOptions.length > 8;
  }

  get value() {
    return this._value;
  }

  set value(newValue) {
    this._value = newValue;
    this.keyValueStore.setItem(AGENT_SELECTOR_KEY, newValue);
    this.args.setAgentId(newValue);
    this.setAllowLLMSelector();
    this.resetTargetRecipients();
  }

  setAllowLLMSelector() {
    if (!this.hasLlmSelector) {
      this.allowLLMSelector = false;
      return;
    }

    const agent = this.enabledAgents.find(
      (innerAgent) => innerAgent.id === this._value
    );

    this.allowLLMSelector = !agent?.force_default_llm;
  }

  get currentLlm() {
    return this.llm;
  }

  set currentLlm(newValue) {
    this.llm = newValue;
    this.keyValueStore.setItem(LLM_SELECTOR_KEY, newValue);

    // Pass the LLM model ID (not user ID) for credit checking
    const bot = this.currentUser.ai_enabled_chat_bots.find(
      (b) => b.id === newValue
    );
    this.args.setLlmId?.(bot?.llm_model_id);
    this.resetTargetRecipients();
  }

  resetTargetRecipients() {
    if (this.allowLLMSelector) {
      const botUsername = this.currentUser.ai_enabled_chat_bots.find(
        (bot) => bot.id === this.llm
      ).username;
      this.args.setTargetRecipient(botUsername);
    } else {
      const agent = this.enabledAgents.find(
        (innerAgent) => innerAgent.id === this._value
      );
      this.args.setTargetRecipient(agent.username || "");
    }
  }

  get llmOptions() {
    const availableBots = this.currentUser.ai_enabled_chat_bots
      .filter((bot) => !bot.is_agent)
      .filter(Boolean);

    return availableBots
      .map((bot) => {
        return {
          id: bot.id,
          name: bot.display_name,
        };
      })
      .sort((a, b) => a.name.localeCompare(b.name));
  }

  get showAgentSelector() {
    return this.botOptions?.length > 1;
  }

  get showLLMSelector() {
    return this.allowLLMSelector && this.llmOptions.length > 1;
  }

  #getAgentIdFromAttrs() {
    const agentName = this.args?.agentName;
    if (agentName) {
      const agent = this.botOptions.find((p) => p.name === agentName);
      if (agent) {
        return agent.id;
      }
    }
  }

  #getLlmIdFromAttrs() {
    const llmName = this.args?.llmName;
    if (llmName) {
      const llm = this.llmOptions.find((l) => l.name === llmName);
      if (llm) {
        return llm.id;
      }
    }
  }

  #loadStoredAgent() {
    let agentId =
      this.#getAgentIdFromAttrs() ||
      this.keyValueStore.getItem(AGENT_SELECTOR_KEY);

    this._value = this.botOptions[0].id;
    if (agentId) {
      agentId = parseInt(agentId, 10);
      if (this.botOptions.some((bot) => bot.id === agentId)) {
        this._value = agentId;
      }
    }

    this.args.setAgentId(this._value);
  }

  #loadStoredLlm() {
    this.setAllowLLMSelector();

    if (this.hasLlmSelector) {
      let llmId =
        this.#getLlmIdFromAttrs() ||
        this.keyValueStore.getItem(LLM_SELECTOR_KEY);
      if (llmId) {
        llmId = parseInt(llmId, 10);
      }

      const llmOption =
        this.llmOptions.find((innerLlmOption) => innerLlmOption.id === llmId) ||
        this.llmOptions[0];

      if (llmOption) {
        llmId = llmOption.id;
      } else {
        llmId = "";
      }

      if (llmId) {
        next(() => {
          this.currentLlm = llmId;
        });
      }
    }
  }

  <template>
    <div class="agent-llm-selector">
      {{#if this.showAgentSelector}}
        <div class="agent-llm-selector__selection-wrapper gpt-agent">
          {{#if @showLabels}}
            <label>{{i18n "discourse_ai.ai_bot.agent"}}</label>
          {{/if}}
          <DropdownSelectBox
            class="agent-llm-selector__agent-dropdown"
            @value={{this.value}}
            @content={{this.botOptions}}
            @options={{hash
              icon=(if @showLabels "angle-down" "robot")
              filterable=this.filterable
            }}
          />
        </div>
      {{/if}}
      {{#if this.showLLMSelector}}
        <div class="agent-llm-selector__selection-wrapper llm-selector">
          {{#if @showLabels}}
            <label>{{i18n "discourse_ai.ai_bot.llm"}}</label>
          {{/if}}
          <DropdownSelectBox
            class="agent-llm-selector__llm-dropdown"
            @value={{this.currentLlm}}
            @content={{this.llmOptions}}
            @options={{hash icon=(if @showLabels "angle-down" "globe")}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
