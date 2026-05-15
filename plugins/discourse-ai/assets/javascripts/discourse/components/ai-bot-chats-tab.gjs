import Component from "@glimmer/component";
import { service } from "@ember/service";
import DNavigationItem from "discourse/components/d-navigation-item";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AiBotChatsTab extends Component {
  @service siteSettings;

  get showTab() {
    return (
      this.args.outletArgs?.viewingSelf && this.siteSettings.ai_bot_enabled
    );
  }

  <template>
    {{#if this.showTab}}
      <DNavigationItem
        @route="discourse-ai-bot-conversations"
        @ariaCurrentContext="subNav"
        class="user-nav__messages-ai-bot-chats"
      >
        {{icon "robot"}}
        <span>{{i18n "discourse_ai.bot_chats.tab_label"}}</span>
      </DNavigationItem>
    {{/if}}
  </template>
}
