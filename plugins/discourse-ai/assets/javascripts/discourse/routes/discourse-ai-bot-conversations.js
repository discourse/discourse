import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class DiscourseAiBotConversationsRoute extends DiscourseRoute {
  @service currentUser;
  @service site;

  queryParams = {
    agent: { replace: true },
    llm: { replace: true },
  };

  beforeModel(transition) {
    if (!this.currentUser && !this.site.ai_bot_anonymous_preview) {
      transition.send("showLogin");
    }
  }
}
