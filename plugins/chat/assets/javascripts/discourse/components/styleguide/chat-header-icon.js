import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import {
  HEADER_INDICATOR_PREFERENCE_ALL_NEW,
  HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
  HEADER_INDICATOR_PREFERENCE_NEVER,
  HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS,
} from "discourse/plugins/chat/discourse/controllers/preferences-chat";

export default class ChatStyleguideChatHeaderIcon extends Component {
  @tracked isActive = false;
  @tracked currentUserInDnD = false;
  @tracked urgentCount;
  @tracked unreadCount;
  @tracked indicatorPreference = HEADER_INDICATOR_PREFERENCE_ALL_NEW;

  get indicatorPreferences() {
    return [
      HEADER_INDICATOR_PREFERENCE_ALL_NEW,
      HEADER_INDICATOR_PREFERENCE_DM_AND_MENTIONS,
      HEADER_INDICATOR_PREFERENCE_ONLY_MENTIONS,
      HEADER_INDICATOR_PREFERENCE_NEVER,
    ];
  }

  @action
  toggleIsActive() {
    this.isActive = !this.isActive;
  }

  @action
  toggleCurrentUserInDnD() {
    this.currentUserInDnD = !this.currentUserInDnD;
  }

  @action
  updateUnreadCount(event) {
    this.unreadCount = event.target.value;
  }

  @action
  updateUrgentCount(event) {
    this.urgentCount = event.target.value;
  }

  @action
  updateIndicatorPreference(value) {
    this.indicatorPreference = value;
  }
}
