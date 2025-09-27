import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AiPersonaLlmSelector from "discourse/plugins/discourse-ai/discourse/components/ai-persona-llm-selector";

function isBotMessage(composer, currentUser) {
  if (
    composer &&
    composer.targetRecipients &&
    currentUser.ai_enabled_chat_bots
  ) {
    const recipients = composer.targetRecipients.split(",");

    return currentUser.ai_enabled_chat_bots
      .filter((bot) => bot.username)
      .any((bot) => recipients.any((username) => username === bot.username));
  }
  return false;
}

export default class BotSelector extends Component {
  static shouldRender(args, context) {
    return (
      context?.currentUser?.ai_enabled_personas &&
      isBotMessage(args.model, context.currentUser)
    );
  }

  @service currentUser;

  @action
  setPersonaIdOnComposer(id) {
    this.args.outletArgs.model.metaData = { ai_persona_id: id };
  }

  @action
  setTargetRecipientsOnComposer(username) {
    this.args.outletArgs.model.set("targetRecipients", username);
  }

  <template>
    <AiPersonaLlmSelector
      @setPersonaId={{this.setPersonaIdOnComposer}}
      @setTargetRecipient={{this.setTargetRecipientsOnComposer}}
    />
  </template>
}
