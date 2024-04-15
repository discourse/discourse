import Controller, { inject as controller } from "@ember/controller";
import { computed } from "@ember/object";
import { service } from "@ember/service";
import I18n from "discourse-i18n";

export default class extends Controller {
  @service router;
  @controller user;

  get viewingSelf() {
    return this.user.viewingSelf;
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

  #linkText(type) {
    const count = this.pmTopicTrackingState?.lookupCount(type, {
      inboxFilter: "user",
    });

    if (count === 0) {
      return I18n.t(`user.messages.${type}`);
    } else {
      return I18n.t(`user.messages.${type}_with_count`, { count });
    }
  }
}
