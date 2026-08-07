import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

const STREAM_KEY = Symbol("user-activity-stream");

export default class UserActivityStream extends DiscourseRoute {
  @service historyStore;

  templateName = "user/stream";

  queryParams = {
    acting_username: { refreshModel: true },
  };

  async model(params) {
    // Reuse the stream we left behind, including the items infinite scroll
    // appended. Reloading it would leave the page shorter than it was, and the
    // scroll position restored by route-scroll-manager would be clamped.
    let stream = this.historyStore.isPoppedState
      ? this.historyStore.get(STREAM_KEY)
      : null;

    if (!stream) {
      stream = this.modelFor("user").stream;
      await stream.filterBy({
        filter: this.userActionType,
        actingUsername: params.acting_username,
      });
      this.historyStore.set(STREAM_KEY, stream);
    }

    return { stream, emptyState: this.emptyState() };
  }

  setupController() {
    super.setupController(...arguments);
    this.controllerFor("user-activity").userActionType = this.userActionType;
  }

  emptyState() {
    const title = i18n("user_activity.no_activity_title");
    const body = "";
    return { title, body };
  }
}
