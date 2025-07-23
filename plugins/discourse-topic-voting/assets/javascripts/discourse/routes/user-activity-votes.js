import UserAction from "discourse/models/user-action";
import UserTopicListRoute from "discourse/routes/user-topic-list";
import { i18n } from "discourse-i18n";

export default class UserActivityVotes extends UserTopicListRoute {
  userActionType = UserAction.TYPES.topics;

  model() {
    return this.store
      .findFiltered("topicList", {
        filter:
          "topics/voted-by/" + this.modelFor("user").get("username_lower"),
      })
      .then((model) => {
        model.set("emptyState", this.emptyState());
        return model;
      });
  }

  emptyState() {
    const user = this.modelFor("user");
    const title = this.isCurrentUser(user)
      ? i18n("topic_voting.no_votes_title_self")
      : i18n("topic_voting.no_votes_title_others", {
          username: user.username,
        });

    return {
      title,
      body: "",
    };
  }
}
