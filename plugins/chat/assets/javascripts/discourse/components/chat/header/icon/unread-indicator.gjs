import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import {
  HEADER_INDICATOR_PREFERENCE_ALL_NEW,
  HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
  HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS,
  HEADER_INDICATOR_PREFERENCE_NEVER,
} from "discourse/plugins/chat/discourse/controllers/preferences-chat";

const MAX_UNREAD_COUNT = 99;

export default class ChatHeaderIconUnreadIndicator extends Component {
  @service chatTrackingStateManager;
  @service currentUser;

  get urgentCount() {
    return (
      this.args.urgentCount ||
      this.chatTrackingStateManager.allChannelUrgentCount
    );
  }

  get mentionCount() {
    return (
      this.args.mentionCount ||
      this.chatTrackingStateManager.allChannelMentionCount
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
    let totalCount = this.onlyMentions ? this.mentionCount : this.unreadCount;

    return (
      totalCount > 0 &&
      this.#hasAnyIndicatorPreference([
        HEADER_INDICATOR_PREFERENCE_ALL_NEW,
        HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
        HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS,
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
    let totalCount = this.onlyMentions ? this.mentionCount : this.unreadCount;
    return totalCount > MAX_UNREAD_COUNT ? `${MAX_UNREAD_COUNT}+` : totalCount;
  }

  get onlyMentions() {
    return this.#hasAnyIndicatorPreference([
      HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS,
    ]);
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
}
