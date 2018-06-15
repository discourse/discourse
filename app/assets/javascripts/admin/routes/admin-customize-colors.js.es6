import ColorScheme from "admin/models/color-scheme";

export default Ember.Route.extend({
  model() {
    return ColorScheme.findAll();
  },

  setupController(controller, model) {
    controller.set("model", model);
  }
});
