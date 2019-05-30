import WatchedWord from "admin/models/watched-word";

export default Discourse.Route.extend({
  queryParams: {
    filter: { replace: true }
  },

  model() {
    return WatchedWord.findAll();
  },

  setupController(controller, model) {
    controller.set("model", model);
    if (model && model.length) {
      controller.set("regularExpressions", model[0].regularExpressions);
    }
  },

  afterModel(watchedWordsList) {
    this.controllerFor("adminWatchedWords").set(
      "allWatchedWords",
      watchedWordsList
    );
  }
});
