import I18n from "I18n";
import Controller, { inject as controller } from "@ember/controller";
import { computed } from "@ember/object";
import { inject as service } from "@ember/service";

export default class extends Controller {
  @service router;
  @controller user;

  get viewingSelf() {
    return this.user.viewingSelf;
  }

  get messagesNav() {
    return document.getElementById("user-navigation-secondary__horizontal-nav");
  }

  @computed("viewingSelf", "router.currentRoute.name", "currentUser.admin")
  get showWarningsWarning() {
    return (
      this.router.currentRoute.name === "userPrivateMessages.user.warnings" &&
      !this.viewingSelf &&
      !this.currentUser.isAdmin
    );
  }

  @computed(
    "pmTopicTrackingState.newIncoming.[]",
    "pmTopicTrackingState.statesModificationCounter"
  )
  get newLinkText() {
    return this.#linkText("new");
  }

  @computed(
    "pmTopicTrackingState.newIncoming.[]",
    "pmTopicTrackingState.statesModificationCounter"
  )
  get unreadLinkText() {
    return this.#linkText("unread");
  }

  #linkText(type) {
    const count =
      this.pmTopicTrackingState?.lookupCount(type, { inboxFilter: "user" }) ||
      0;

    if (count === 0) {
      return I18n.t(`user.messages.${type}`);
    } else {
      return I18n.t(`user.messages.${type}_with_count`, { count });
    }
  }
}
