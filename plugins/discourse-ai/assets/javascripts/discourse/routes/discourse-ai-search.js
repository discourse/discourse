import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class DiscourseAiSearchRoute extends DiscourseRoute {
  @service currentUser;
  @service router;

  beforeModel(transition) {
    if (!this.currentUser) {
      transition.send("showLogin");
    } else if (!this.currentUser.can_use_ask_ai) {
      this.router.replaceWith("full-page-search");
    }
  }

  titleToken() {
    return i18n("discourse_ai.ai_search.title");
  }
}
