import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import I18n from "discourse-i18n";

export default class extends Controller {
  @service pmTopicTrackingState;
  @controller user;

  get viewingSelf() {
    return this.user.get("viewingSelf");
  }

  get newLinkText() {
    return this.#linkText("new");
  }

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
