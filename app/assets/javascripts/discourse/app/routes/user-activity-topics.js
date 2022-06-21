import UserAction from "discourse/models/user-action";
import UserTopicListRoute from "discourse/routes/user-topic-list";
import { action } from "@ember/object";
import I18n from "I18n";

export default UserTopicListRoute.extend({
  userActionType: UserAction.TYPES.topics,

  model() {
    return this.store
      .findFiltered("topicList", {
        filter:
          "topics/created-by/" + this.modelFor("user").get("username_lower"),
      })
      .then((model) => {
        // andrei: we agreed that this is an anti pattern,
        // it's better to avoid mutating a rest model like this
        // this place we'll be refactored later
        // see https://github.com/discourse/discourse/pull/14313#discussion_r708784704
        model.set("emptyState", this.emptyState());
        return model;
      });
  },

  afterModel(model, transition) {
    if (!this.isPoppedState(transition)) {
      this.session.set("topicListScrollPosition", null);
    }
  },

  emptyState() {
    const user = this.modelFor("user");
    const title = this.isCurrentUser(user)
      ? I18n.t("user_activity.no_topics_title")
      : I18n.t("user_activity.no_topics_title_others", {
          username: user.username,
        });

    return {
      title,
      body: "",
    };
  },

  @action
  triggerRefresh() {
    this.refresh();
  },
});
