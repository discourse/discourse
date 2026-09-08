import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { hasPinsDismissal } from "discourse/plugins/chat/discourse/lib/chat-pinned-bar-dismissal";

export default class ChatNavbarPinnedMessagesButton extends Component {
  @service router;
  @service siteSettings;
  @service chatStateManager;

  pinnedMessagesLabel = i18n("chat.pinned_messages.title");

  handleClick = (event) => {
    event.stopPropagation();
  };

  // only the way back to the pins panel while the bar itself is dismissed
  get showButton() {
    return (
      this.siteSettings.chat_pinned_messages &&
      !this.chatStateManager.isDrawerCollapsed &&
      this.args.channel?.hasPinnedMessages &&
      hasPinsDismissal(this.args.channel) &&
      this.router.currentRoute?.name !== "chat.channel.pins"
    );
  }

  <template>
    {{#if this.showButton}}
      <LinkTo
        class="c-navbar__pinned-messages-btn btn no-text btn-transparent"
        title={{this.pinnedMessagesLabel}}
        @models={{@channel.routeModels}}
        @route="chat.channel.pins"
        {{on "click" this.handleClick}}
      >
        {{! no unread dot: a pin newer than the dismissal brings the bar itself
        back, so this button never needs to signal newness }}
        {{dIcon "thumbtack"}}
      </LinkTo>
    {{/if}}
  </template>
}
