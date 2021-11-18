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

  emptyState() {
    return {
      title: I18n.t("user_activity.no_topics_title"),
      body: "",
    };
  },

  @action
  triggerRefresh() {
    this.refresh();
  },
});
