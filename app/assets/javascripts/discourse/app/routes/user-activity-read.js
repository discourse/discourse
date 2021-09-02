import UserAction from "discourse/models/user-action";
import UserTopicListRoute from "discourse/routes/user-topic-list";
import { action } from "@ember/object";

export default UserTopicListRoute.extend({
  userActionType: UserAction.TYPES.topics,

  model() {
    return this.store.findFiltered("topicList", {
      filter: "read",
    });
  },

  @action
  refresh() {
    this.refresh();
  },
});
