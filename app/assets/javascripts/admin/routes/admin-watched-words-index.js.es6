export default Discourse.Route.extend({
  beforeModel() {
    this.replaceWith(
      "adminWatchedWords.action",
      this.modelFor("adminWatchedWords")[0].nameKey
    );
  }
});
