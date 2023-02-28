import { inject as service } from "@ember/service";
import Component from "@glimmer/component";

export default class ChatHeaderIconUnreadIndicator extends Component {
  @service chatChannelsManager;
  @service currentUser;

  get showUrgentIndicator() {
    return (
      this.chatChannelsManager.unreadUrgentCount > 0 &&
      this.#hasAnyIndicatorPreference(["all_new", "dm_and_mentions"])
    );
  }

  get showUnreadIndicator() {
    return (
      this.chatChannelsManager.unreadCount > 0 &&
      this.#hasAnyIndicatorPreference(["all_new"])
    );
  }

  get indicatorPreference() {
    return this.currentUser.user_option.chat_header_indicator_preference;
  }

  #hasAnyIndicatorPreference(preferences) {
    if (!this.currentUser || this.indicatorPreference === "never") {
      return false;
    }

    return preferences.includes(this.indicatorPreference);
  }
}
