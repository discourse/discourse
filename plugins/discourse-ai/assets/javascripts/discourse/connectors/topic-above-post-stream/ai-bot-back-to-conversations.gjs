import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class AiBotBackToConversations extends Component {
  @service currentUser;

  get shouldShow() {
    const topic = this.args.outletArgs?.model;
    return (
      topic?.archetype === "private_message" &&
      topic?.user_id === this.currentUser?.id &&
      topic?.is_bot_pm
    );
  }

  <template>
    {{#if this.shouldShow}}
      <a
        href={{getURL "/discourse-ai/ai-bot/conversations"}}
        class="ai-bot-back-to-conversations"
      >
        {{icon "chevron-left"}}
        <span>{{i18n
            "discourse_ai.ai_bot.conversations.back_to_conversations"
          }}</span>
      </a>
    {{/if}}
  </template>
}
