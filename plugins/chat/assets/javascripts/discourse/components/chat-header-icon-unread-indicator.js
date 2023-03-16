import { inject as service } from "@ember/service";
import Component from "@glimmer/component";
import {
  HEADER_INDICATOR_PREFERENCE_ALL_NEW,
  HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
  HEADER_INDICATOR_PREFERENCE_NEVER,
} from "../controllers/preferences-chat";

export default class ChatHeaderIconUnreadIndicator extends Component {
  @service chatChannelsManager;
  @service currentUser;

  get showUrgentIndicator() {
    return (
      this.chatChannelsManager.unreadUrgentCount > 0 &&
      this.#hasAnyIndicatorPreference([
        HEADER_INDICATOR_PREFERENCE_ALL_NEW,
        HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
      ])
    );
  }

  get showUnreadIndicator() {
    return (
      this.chatChannelsManager.unreadCount > 0 &&
      this.#hasAnyIndicatorPreference([HEADER_INDICATOR_PREFERENCE_ALL_NEW])
    );
  }

  get indicatorPreference() {
    return this.currentUser.user_option.chat_header_indicator_preference;
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
