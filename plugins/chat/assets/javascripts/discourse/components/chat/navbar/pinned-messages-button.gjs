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

  pinnedMessagesLabel = i18n("chat.pinned_messages.title");

  handleClick = (event) => {
    event.stopPropagation();
  };

  // Only shown while the pinned bar is dismissed, as the way back to the pins
  // panel (whose footer offers to show the bar again). While the bar is
  // visible its own list button is the entry point.
  get showButton() {
    return (
      this.siteSettings.chat_pinned_messages &&
      this.args.channel?.hasPinnedMessages &&
      !this.args.channel.canManagePins &&
      hasPinsDismissal(this.args.channel) &&
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
        {{dIcon "thumbtack"}}
        {{#if @channel.hasUnseenPins}}
          <span class="c-navbar__pinned-messages-btn__unread-indicator"></span>
        {{/if}}
      </LinkTo>
    {{/if}}
  </template>
}
