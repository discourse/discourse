import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import {
  HEADER_INDICATOR_PREFERENCE_ALL_NEW,
  HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
  HEADER_INDICATOR_PREFERENCE_NEVER,
} from "discourse/plugins/chat/discourse/controllers/preferences-chat";

const MAX_UNREAD_COUNT = 99;

export default class ChatHeaderIconUnreadIndicator extends Component {
  <template>
    {{#if this.showUrgentIndicator}}
      <div class="chat-channel-unread-indicator -urgent">
        <div class="chat-channel-unread-indicator__number">
          {{this.unreadCountLabel}}
        </div>
      </div>
    {{else if this.showUnreadIndicator}}
      <div class="chat-channel-unread-indicator"></div>
    {{/if}}
  </template>

  @service chatTrackingStateManager;
  @service currentUser;

  get urgentCount() {
    return (
      this.args.urgentCount ||
      this.chatTrackingStateManager.allChannelUrgentCount
    );
  }

  get unreadCount() {
    return (
      this.args.unreadCount ||
      this.chatTrackingStateManager.publicChannelUnreadCount
    );
  }

  get indicatorPreference() {
    return (
      this.args.indicatorPreference ||
      this.currentUser.user_option.chat_header_indicator_preference
    );
  }

  get showUrgentIndicator() {
    return (
      this.urgentCount > 0 &&
      this.#hasAnyIndicatorPreference([
        HEADER_INDICATOR_PREFERENCE_ALL_NEW,
        HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
      ])
    );
  }

  get showUnreadIndicator() {
    return (
      this.unreadCount > 0 &&
      this.#hasAnyIndicatorPreference([HEADER_INDICATOR_PREFERENCE_ALL_NEW])
    );
  }

  get unreadCountLabel() {
    return this.urgentCount > MAX_UNREAD_COUNT
      ? `${MAX_UNREAD_COUNT}+`
      : this.urgentCount;
  }

  #hasAnyIndicatorPreference(preferences) {
    if (
      !this.currentUser ||
      this.indicatorPreference === HEADER_INDICATOR_PREFERENCE_NEVER
    ) {
      return false;
    }

    return preferences.includes(this.indicatorPreference);
  }
}
