import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

export default class AiAskButton extends Component {
  @service currentUser;
  @service siteSettings;

  get shouldShow() {
    return (
      this.currentUser?.ai_enabled_chat_bots?.length > 0 &&
      this.siteSettings.ai_bot_add_to_header
    );
  }

  get href() {
    return getURL("/discourse-ai/ai-bot/conversations?preserveSidebar=true");
  }

  <template>
    {{#if this.shouldShow}}
      <a
        href={{this.href}}
        class="ai-ask-button"
        title={{i18n "discourse_ai.ai_bot.ask_button.title"}}
      >
        {{icon "robot"}}
        <span class="ai-ask-button__label">
          {{i18n "discourse_ai.ai_bot.ask_button.label"}}
        </span>
      </a>
    {{/if}}
  </template>
}
