import { allCategories } from "discourse/plugins/styleguide/discourse/lib/styleguide";

export default Ember.Route.extend({
  model() {
    return allCategories();
  },

  setupController(controller, categories) {
    controller.set("categories", categories);
  },
});
