import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";
import { slugify } from "discourse/lib/utilities";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const AGENT_SELECTOR_KEY = "ai_agent_selector_id";
const LEGACY_LLM_SELECTOR_KEY = "ai_llm_selector_id";
const LLM_SELECTOR_KEY = "ai_llm_selector_model_id";
const HEADING_COLLECTION = "HEADING_COLLECTION";

const MenuHeading = <template>
  <div class="agent-llm-selector__menu-heading">
    <span>{{@collection.content.label}}</span>
    {{#if @collection.content.settingsPath}}
      <a
        aria-label={{@collection.content.settingsLabel}}
        class="agent-llm-selector__menu-settings"
        href={{getURL @collection.content.settingsPath}}
        title={{@collection.content.settingsLabel}}
      >{{dIcon "wrench"}}</a>
    {{/if}}
  </div>
</template>;

class AgentLlmDropdown extends DropdownSelectBox {
  init() {
    super.init(...arguments);

    if (this.menuHeading) {
      this.prependCollection(HEADING_COLLECTION);
    }
  }

  click(event) {
    // Let Discourse's root click interceptor route the settings link.
    if (!event.target.closest(".agent-llm-selector__menu-settings")) {
      super.click(event);
    }
  }

  modifyComponentForCollection(identifier) {
    if (identifier === HEADING_COLLECTION) {
      return MenuHeading;
    }
  }

  modifyContentForCollection(identifier) {
    if (identifier === HEADING_COLLECTION) {
      return this.menuHeading;
    }
  }
}

export default class AiAgentLlmSelector extends Component {
  @service currentUser;
  @service keyValueStore;

  @tracked allowLLMSelector = true;
  @tracked llm;

  #agentId = tracked(undefined);
  #preferredLlmId;

  constructor() {
    super(...arguments);

    if (this.botOptions.length) {
      this.#loadStoredAgent();
      this.#loadStoredLlm();

      next(() => {
        this.resetTargetRecipient();
        this.notifySelectionChanged();
      });
    }
  }

  get value() {
    return this.#agentId.value;
  }

  set value(newValue) {
    this.#agentId.value = newValue;
    this.keyValueStore.setItem(AGENT_SELECTOR_KEY, newValue);
    this.args.setAgentId(newValue);
    this.setAllowLLMSelector();
    this.#selectModelForAgent();
    this.resetTargetRecipient();
    this.notifySelectionChanged();
  }

  get currentLlm() {
    return this.llm;
  }

  set currentLlm(newValue) {
    this.#setEffectiveLlm(newValue, { persistPreference: true });
    this.notifySelectionChanged();
  }

  get composer() {
    return this.args?.outletArgs?.model;
  }

  get hasLlmSelector() {
    return this.llmOptions.length > 0;
  }

  get hasUnavailableLlm() {
    return this.llm && !this.llmOptions.some((model) => model.id === this.llm);
  }

  get enabledAgents() {
    return this.currentUser.ai_enabled_agents || [];
  }

  get selectedAgent() {
    return this.enabledAgents.find((agent) => agent.id === this.value);
  }

  get botOptions() {
    return this.enabledAgents
      .filter((agent) => agent.allow_personal_messages && agent.username)
      .map((agent) => ({
        id: agent.id,
        name: agent.name,
        description: agent.description,
      }));
  }

  get filterable() {
    return this.botOptions.length > 8;
  }

  get llmOptions() {
    return (this.currentUser.ai_available_llm_models || [])
      .map((model) => ({ id: model.id, name: model.display_name }))
      .sort((first, second) => first.name.localeCompare(second.name));
  }

  get agentMenuHeading() {
    if (this.args.showMenuHeadings) {
      return {
        label: i18n("discourse_ai.ai_bot.agent_menu_heading"),
        settingsLabel: i18n("discourse_ai.ai_agent.manage_agents"),
        settingsPath: this.currentUser.admin
          ? "/admin/plugins/discourse-ai/ai-agents"
          : null,
      };
    }
  }

  get llmMenuHeading() {
    if (this.args.showMenuHeadings) {
      return {
        label: i18n("discourse_ai.ai_bot.model_menu_heading"),
        settingsLabel: i18n("discourse_ai.ai_bot.manage_language_models"),
        settingsPath: this.currentUser.admin
          ? "/admin/plugins/discourse-ai/ai-models"
          : null,
      };
    }
  }

  get showAgentSelector() {
    return (
      this.botOptions.length > 1 || (this.args.agentId && !this.selectedAgent)
    );
  }

  get showLLMSelector() {
    return (
      this.allowLLMSelector &&
      (this.llmOptions.length > 1 || this.hasUnavailableLlm)
    );
  }

  @action
  changeAgent(value) {
    this.value = value;
  }

  @action
  changeLlm(value) {
    this.currentLlm = value;
  }

  setAllowLLMSelector() {
    this.allowLLMSelector =
      this.hasLlmSelector && !this.selectedAgent?.force_default_llm;
  }

  notifySelectionChanged() {
    if (!this.args.onSelectionChanged) {
      return;
    }

    const agentName = this.showAgentSelector ? this.selectedAgent?.name : null;
    let llmName = null;
    if (this.selectedAgent?.force_default_llm) {
      llmName = this.selectedAgent.default_llm_name;
    } else if (this.showLLMSelector) {
      llmName = this.llmOptions.find((model) => model.id === this.llm)?.name;
    }

    this.args.onSelectionChanged({ agentName, llmName });
  }

  resetTargetRecipient() {
    this.args.setTargetRecipient(this.selectedAgent?.username || "");
  }

  #getAgentIdFromAttrs() {
    if (this.args.agentId) {
      return parseInt(this.args.agentId, 10);
    }

    const agentName = this.args.agentName;
    if (agentName) {
      const slug = slugify(agentName);
      const agent = this.botOptions.find(
        (option) =>
          option.name === agentName || (slug && slugify(option.name) === slug)
      );
      return agent?.id;
    }
  }

  #getLlmIdFromAttrs() {
    if (this.args.llmModelId) {
      return parseInt(this.args.llmModelId, 10);
    }

    const llmName = this.args.llmName;
    if (llmName) {
      const slug = slugify(llmName);
      const llm = this.llmOptions.find(
        (option) =>
          option.name === llmName || (slug && slugify(option.name) === slug)
      );
      return llm?.id || llmName;
    }
  }

  #loadStoredAgent() {
    const attrAgentId = this.#getAgentIdFromAttrs();
    let agentId =
      attrAgentId ??
      parseInt(this.keyValueStore.getItem(AGENT_SELECTOR_KEY), 10);

    if (!this.botOptions.some((agent) => agent.id === agentId)) {
      agentId = attrAgentId === undefined ? this.botOptions[0].id : null;
    }
    this.#agentId.value = agentId;
    this.setAllowLLMSelector();
    next(() => this.args.setAgentId(agentId));
  }

  #loadStoredLlm() {
    const hasExplicitLlm =
      (this.args.llmModelId !== undefined &&
        this.args.llmModelId !== null &&
        this.args.llmModelId !== "") ||
      Boolean(this.args.llmName);
    let llmId = this.selectedAgent?.force_default_llm
      ? null
      : this.#getLlmIdFromAttrs();
    if (!hasExplicitLlm) {
      llmId ||= parseInt(this.keyValueStore.getItem(LLM_SELECTOR_KEY), 10);
      llmId ||= this.#translateLegacyLlmId();
    }
    const available = this.llmOptions.some((model) => model.id === llmId);
    if (!available && !hasExplicitLlm) {
      llmId = this.llmOptions[0]?.id || null;
    }

    this.#preferredLlmId = llmId;
    if (llmId && available) {
      this.keyValueStore.setItem(LLM_SELECTOR_KEY, llmId);
    }

    const effectiveLlmId = this.selectedAgent?.force_default_llm
      ? this.selectedAgent.default_llm_id
      : llmId;
    this.llm = effectiveLlmId;
    next(() => this.args.setLlmId?.(effectiveLlmId || null));
  }

  #selectModelForAgent() {
    if (this.selectedAgent?.force_default_llm) {
      this.#setEffectiveLlm(this.selectedAgent.default_llm_id);
    } else {
      const llmId = this.llmOptions.some(
        (model) => model.id === this.#preferredLlmId
      )
        ? this.#preferredLlmId
        : this.llmOptions[0]?.id || null;
      this.#setEffectiveLlm(llmId, { persistPreference: true });
    }
  }

  #setEffectiveLlm(newValue, { persistPreference = false } = {}) {
    this.llm = newValue;
    if (persistPreference) {
      this.#preferredLlmId = newValue;
      this.keyValueStore.setItem(LLM_SELECTOR_KEY, newValue);
    }
    this.args.setLlmId?.(newValue || null);
  }

  #translateLegacyLlmId() {
    const legacyUserId = parseInt(
      this.keyValueStore.getItem(LEGACY_LLM_SELECTOR_KEY),
      10
    );
    return this.currentUser.ai_available_llm_models?.find(
      (model) => model.legacy_user_id === legacyUserId
    )?.id;
  }

  <template>
    <div class="agent-llm-selector">
      {{#if this.showAgentSelector}}
        <div class="agent-llm-selector__selection-wrapper gpt-agent">
          <AgentLlmDropdown
            class="agent-llm-selector__agent-dropdown"
            @content={{this.botOptions}}
            @menuHeading={{this.agentMenuHeading}}
            @onChange={{this.changeAgent}}
            @options={{hash
              customStyle=true
              filterable=this.filterable
              icon=(if @showMenuHeadings "angle-down" "robot")
              mobilePlacementStrategy=(if @showMenuHeadings "fixed")
            }}
            @value={{this.value}}
          />
        </div>
      {{/if}}
      {{#if this.showLLMSelector}}
        <div class="agent-llm-selector__selection-wrapper llm-selector">
          <AgentLlmDropdown
            class="agent-llm-selector__llm-dropdown"
            @content={{this.llmOptions}}
            @menuHeading={{this.llmMenuHeading}}
            @onChange={{this.changeLlm}}
            @options={{hash
              customStyle=true
              icon=(if @showMenuHeadings "angle-down" "globe")
              mobilePlacementStrategy=(if @showMenuHeadings "fixed")
            }}
            @value={{this.currentLlm}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
