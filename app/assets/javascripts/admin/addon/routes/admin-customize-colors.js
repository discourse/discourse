import ColorScheme from "admin/models/color-scheme";
import Route from "@ember/routing/route";

export default Route.extend({
  model() {
    return ColorScheme.findAll();
  },

  setupController(controller, model) {
    controller.set("model", model);
  },
});
