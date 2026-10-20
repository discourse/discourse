import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import { combinedSearchActive } from "../lib/ai-search-scope.js";

export default class DiscourseAiSearchRoute extends DiscourseRoute {
  @service currentUser;
  @service router;
  @service siteSettings;

  beforeModel(transition) {
    if (!this.currentUser) {
      transition.send("showLogin");
    } else if (!combinedSearchActive(this.siteSettings, this.currentUser)) {
      this.router.replaceWith("full-page-search");
    }
  }

  titleToken() {
    return i18n("discourse_ai.ai_search.title");
  }
}
