import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminWatchedWordsIndexRoute extends DiscourseRoute {
  @service router;

  beforeModel() {
    this.router.replaceWith(
      "adminWatchedWords.action",
      this.modelFor("adminWatchedWords")[0].nameKey
    );
  }
}
