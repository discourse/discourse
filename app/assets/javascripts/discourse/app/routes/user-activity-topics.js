import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import UserAction from "discourse/models/user-action";
import UserTopicListRoute from "discourse/routes/user-topic-list";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

export default class UserActivityTopics extends UserTopicListRoute {
  userActionType = UserAction.TYPES.topics;

  async model(params = {}) {
    const model = await this.store.findFiltered("topicList", {
      filter: `topics/created-by/${this.modelFor("user").get(
        "username_lower"
      )}`,
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
    const user = this.modelFor("user");
    let title, body;
    if (this.isCurrentUser(user)) {
      title = I18n.t("user_activity.no_topics_title");
      body = htmlSafe(
        I18n.t("user_activity.no_topics_body", {
          searchUrl: getURL("/search"),
        })
      );
    } else {
      title = I18n.t("user_activity.no_topics_title_others", {
        username: user.username,
      });
      body = "";
    }

    return { title, body };
  }

  titleToken() {
    return I18n.t("user_action_groups.4");
  }

  @action
  triggerRefresh() {
    this.refresh();
  }
}
