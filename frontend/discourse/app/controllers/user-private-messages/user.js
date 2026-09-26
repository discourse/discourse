import Controller, { inject as controller } from "@ember/controller";
import { service } from "discourse/lib/service";
import { i18n } from "discourse-i18n";
import CurrentUserService from "discourse/services/current-user";
import PmTopicTrackingStateService from "discourse/services/pm-topic-tracking-state";

export default class extends Controller {
  @service(() => CurrentUserService) currentUser;
  @service(() => PmTopicTrackingStateService) pmTopicTrackingState;
  @service router;
  @controller user;

  get viewingSelf() {
    return this.user.get("viewingSelf");
  }

  get showWarningsWarning() {
    return (
      this.router.currentRoute.name === "userPrivateMessages.user.warnings" &&
      !this.viewingSelf &&
      !this.currentUser.isAdmin
    );
  }

  get newLinkText() {
    return this.#linkText("new");
  }

  get unreadLinkText() {
    return this.#linkText("unread");
  }

  #linkText(type) {
    const count = this.pmTopicTrackingState?.lookupCount(type, {
      inboxFilter: "user",
    });

    if (count === 0) {
      return i18n(`user.messages.${type}`);
    } else {
      return i18n(`user.messages.${type}_with_count`, { count });
    }
  }
}
