import DiscourseRoute from "discourse/routes/discourse";

export default class AdminWatchedWordsIndexRoute extends DiscourseRoute {
  beforeModel() {
    this.replaceWith(
      "adminWatchedWords.action",
      this.modelFor("adminWatchedWords")[0].nameKey
    );
  }
}
