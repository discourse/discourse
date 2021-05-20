import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";

export default Route.extend({
  model() {
    return this.store.createRecord("api-key");
  },

  setupController(controller, model) {
    ajax("/admin/api/keys/scopes.json").then((data) => {
      controller.setProperties({
        scopes: data.scopes,
        model,
      });
    });
  },
});
