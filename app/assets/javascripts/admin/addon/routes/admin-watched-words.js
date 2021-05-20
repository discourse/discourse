import DiscourseRoute from "discourse/routes/discourse";
import WatchedWord from "admin/models/watched-word";

export default DiscourseRoute.extend({
  queryParams: {
    filter: { replace: true },
  },

  model() {
    return WatchedWord.findAll();
  },

  setupController(controller, model) {
    controller.set("model", model);
  },

  afterModel(watchedWordsList) {
    this.controllerFor("adminWatchedWords").set(
      "allWatchedWords",
      watchedWordsList
    );
  },
});
