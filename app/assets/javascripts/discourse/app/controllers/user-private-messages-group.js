import I18n from "I18n";
import Controller, { inject as controller } from "@ember/controller";
import { action, computed } from "@ember/object";

export default class extends Controller {
  @controller user;

  get viewingSelf() {
    return this.user.viewingSelf;
  }

  @computed(
    "pmTopicTrackingState.newIncoming.[]",
    "pmTopicTrackingState.statesModificationCounter",
    "pmTopicTrackingState.isTracking"
  )
  get newLinkText() {
    return this.#linkText("new");
  }

  @computed(
    "pmTopicTrackingState.newIncoming.[]",
    "pmTopicTrackingState.statesModificationCounter",
    "pmTopicTrackingState.isTracking"
  )
  get unreadLinkText() {
    return this.#linkText("unread");
  }

  get navigationControlsButton() {
    return document.getElementById("navigation-controls__button");
  }

  #linkText(type) {
    const count = this.pmTopicTrackingState?.lookupCount(type, {
      inboxFilter: "group",
      groupName: this.group.name,
    });

    if (count === 0) {
      return I18n.t(`user.messages.${type}`);
    } else {
      return I18n.t(`user.messages.${type}_with_count`, { count });
    }
  }

  @action
  changeGroupNotificationLevel(notificationLevel) {
    this.group.setNotification(notificationLevel, this.get("user.model.id"));
  }
}
