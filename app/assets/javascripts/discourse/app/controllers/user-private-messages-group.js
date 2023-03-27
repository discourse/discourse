import I18n from "I18n";
import Controller, { inject as controller } from "@ember/controller";
import { computed } from "@ember/object";

export default class extends Controller {
  @controller user;

  get viewingSelf() {
    return this.user.viewingSelf;
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
    const count = this.pmTopicTrackingState?.lookupCount(type, {
      inboxFilter: "group",
      groupName: this.groupName,
    });

    if (count === 0) {
      return I18n.t(`user.messages.${type}`);
    } else {
      return I18n.t(`user.messages.${type}_with_count`, { count });
    }
  }
}
