import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatNavbarPinnedMessagesButton extends Component {
  @service router;
  @service siteSettings;

  pinnedMessagesLabel = i18n("chat.pinned_messages.title");

  handleClick = (event) => {
    event.stopPropagation();
  };

  get showButton() {
    return (
      this.siteSettings.chat_pinned_messages &&
      this.args.channel?.hasPinnedMessages &&
      this.router.currentRoute?.name !== "chat.channel.pins"
    );
  }

  <template>
    {{#if this.showButton}}
      <LinkTo
        @route="chat.channel.pins"
        @models={{@channel.routeModels}}
        title={{this.pinnedMessagesLabel}}
        class="c-navbar__pinned-messages-btn btn no-text btn-transparent"
        {{on "click" this.handleClick}}
      >
        {{icon "thumbtack"}}
        {{#if @channel.hasUnseenPins}}
          <span class="c-navbar__pinned-messages-btn__unread-indicator"></span>
        {{/if}}
      </LinkTo>
    {{/if}}
  </template>
}
