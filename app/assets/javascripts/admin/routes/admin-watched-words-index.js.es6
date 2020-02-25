import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  beforeModel() {
    this.replaceWith(
      "adminWatchedWords.action",
      this.modelFor("adminWatchedWords")[0].nameKey
    );
  }
});
