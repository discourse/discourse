import UserAction from "discourse/models/user-action";
import UserTopicListRoute from "discourse/routes/user-topic-list";
import { action } from "@ember/object";
import I18n from "I18n";

export default UserTopicListRoute.extend({
  userActionType: UserAction.TYPES.topics,

  model: function () {
    return this.store
      .findFiltered("topicList", {
        filter:
          "topics/created-by/" + this.modelFor("user").get("username_lower"),
      })
      .then((model) => {
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
  refresh() {
    this.refresh();
  },
});
