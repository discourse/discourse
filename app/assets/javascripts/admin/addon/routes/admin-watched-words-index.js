import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default class AdminWatchedWordsIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith(
      "adminWatchedWords.action",
      this.modelFor("adminWatchedWords")[0].nameKey
    );
  }
}
