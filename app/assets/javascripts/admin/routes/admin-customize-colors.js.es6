import Route from "@ember/routing/route";
import ColorScheme from "admin/models/color-scheme";

export default Route.extend({
  model() {
    return ColorScheme.findAll();
  },

  setupController(controller, model) {
    controller.set("model", model);
  }
});
