import Component from "@glimmer/component";
import { action } from "@ember/object";
import AiAgentLlmSelector from "discourse/plugins/discourse-ai/discourse/components/ai-agent-llm-selector";

function isBotMessage(composer, currentUser) {
  if (composer?.topic?.is_bot_pm) {
    return true;
  }

  const recipients = composer?.targetRecipients?.split(",") || [];
  return currentUser.ai_enabled_agents?.some((agent) =>
    recipients.includes(agent.username)
  );
}

export default class BotSelector extends Component {
  static shouldRender(args, { currentUser }) {
    return (
      currentUser?.ai_enabled_agents && isBotMessage(args.model, currentUser)
    );
  }

  get composer() {
    return this.args.outletArgs.model;
  }

  get agentId() {
    return (
      this.composer.aiAgentId ||
      this.composer.metaData?.ai_agent_id ||
      this.composer.topic?.ai_agent_id
    );
  }

  get llmModelId() {
    return (
      this.composer.aiLlmModelId ||
      this.composer.metaData?.ai_llm_model_id ||
      this.composer.topic?.ai_llm_model_id
    );
  }

  @action
  setAgentIdOnComposer(id) {
    this.composer.set("aiAgentId", id);
    this.composer.metaData = {
      ...this.composer.metaData,
      ai_agent_id: id,
    };
  }

  @action
  setLlmIdOnComposer(id) {
    this.composer.set("aiLlmModelId", id);
    this.composer.metaData = {
      ...this.composer.metaData,
      ai_llm_model_id: id,
    };
  }

  @action
  setTargetRecipientsOnComposer(username) {
    if (!this.composer.topic?.is_bot_pm) {
      this.composer.set("targetRecipients", username);
    }
  }

  <template>
    <AiAgentLlmSelector
      @agentId={{this.agentId}}
      @llmModelId={{this.llmModelId}}
      @outletArgs={{@outletArgs}}
      @setAgentId={{this.setAgentIdOnComposer}}
      @setLlmId={{this.setLlmIdOnComposer}}
      @setTargetRecipient={{this.setTargetRecipientsOnComposer}}
    />
  </template>
}
