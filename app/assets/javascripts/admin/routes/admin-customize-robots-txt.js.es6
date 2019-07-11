import { ajax } from "discourse/lib/ajax";

export default Ember.Route.extend({
  model() {
    return ajax("/admin/customize/robots");
  },

  setupController(controller, model) {
    this._super(...arguments);
    controller.set("buffer", model.content);
  }
});
