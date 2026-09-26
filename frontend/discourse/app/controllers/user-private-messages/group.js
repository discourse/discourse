import Controller, { inject as controller } from "@ember/controller";
import { service } from "discourse/lib/service";
import { i18n } from "discourse-i18n";
import PmTopicTrackingStateService from "discourse/services/pm-topic-tracking-state";

export default class extends Controller {
  @service(() => PmTopicTrackingStateService) pmTopicTrackingState;
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

  #linkText(type) {
    const count = this.pmTopicTrackingState?.lookupCount(type, {
      inboxFilter: "group",
      groupName: this.group.name,
    });

    if (count === 0) {
      return i18n(`user.messages.${type}`);
    } else {
      return i18n(`user.messages.${type}_with_count`, { count });
    }
  }
}
