import DiscourseRoute from "discourse/routes/discourse";
import WatchedWord from "admin/models/watched-word";

export default DiscourseRoute.extend({
  queryParams: {
    filter: { replace: true },
  },

  model() {
    return WatchedWord.findAll();
  },

  afterModel(model) {
    const controller = this.controllerFor("adminWatchedWords");
    controller.set("allWatchedWords", model);
  },
});
