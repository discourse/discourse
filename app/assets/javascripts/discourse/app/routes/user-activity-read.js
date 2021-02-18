import UserAction from "discourse/models/user-action";
import UserTopicListRoute from "discourse/routes/user-topic-list";

export default UserTopicListRoute.extend({
  userActionType: UserAction.TYPES.topics,

  model() {
    return this.store.findFiltered("topicList", {
      filter: "read",
    });
  },
});
