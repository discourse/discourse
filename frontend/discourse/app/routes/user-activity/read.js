import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import getURL from "discourse/lib/get-url";
import { iconHTML } from "discourse/lib/icon-library";
import UserAction from "discourse/models/user-action";
import UserTopicListRoute from "discourse/routes/user-topic-list";
import { i18n } from "discourse-i18n";

export default class UserActivityRead extends UserTopicListRoute {
  userActionType = UserAction.TYPES.topics;

  async model(params = {}) {
    const model = await this.store.findFiltered("topicList", {
      filter: "read",
      params,
    });

    // andrei: we agreed that this is an anti pattern,
    // it's better to avoid mutating a rest model like this
    // this place we'll be refactored later
    // see https://github.com/discourse/discourse/pull/14313#discussion_r708784704
    model.set("emptyState", this.emptyState());
    return model;
  }

  emptyState() {
    const title = i18n("user_activity.no_read_topics_title");
    const body = htmlSafe(
      i18n("user_activity.no_read_topics_body", {
        topUrl: getURL("/top"),
        categoriesUrl: getURL("/categories"),
        searchIcon: iconHTML("magnifying-glass"),
      })
    );
    return { title, body };
  }

  titleToken() {
    return `${i18n("user.read")}`;
  }

  @action
  triggerRefresh() {
    this.refresh();
  }
}
