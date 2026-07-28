import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiBotConversationsRoute extends DiscourseRoute {
  @service currentUser;

  queryParams = {
    agent: { replace: true },
    llm: { replace: true },
  };

  beforeModel(transition) {
    if (!this.currentUser) {
      transition.send("showLogin");
    }
  }
}
