import Component from "@glimmer/component";
import { action } from "@ember/object";
import AiAgentLlmSelector from "discourse/plugins/discourse-ai/discourse/components/ai-agent-llm-selector";

function isBotMessage(composer, currentUser) {
  if (
    composer &&
    composer.targetRecipients &&
    currentUser.ai_enabled_chat_bots
  ) {
    const recipients = composer.targetRecipients.split(",");

    return currentUser.ai_enabled_chat_bots
      .filter((bot) => bot.username)
      .some((bot) => recipients.some((username) => username === bot.username));
  }
  return false;
}

export default class BotSelector extends Component {
  static shouldRender(args, { currentUser }) {
    return (
      currentUser?.ai_enabled_agents && isBotMessage(args.model, currentUser)
    );
  }

  @action
  setAgentIdOnComposer(id) {
    this.args.outletArgs.model.metaData = {
      ai_agent_id: id,
    };
  }

  @action
  setTargetRecipientsOnComposer(username) {
    this.args.outletArgs.model.set("targetRecipients", username);
  }

  <template>
    <AiAgentLlmSelector
      @setAgentId={{this.setAgentIdOnComposer}}
      @setTargetRecipient={{this.setTargetRecipientsOnComposer}}
    />
  </template>
}
