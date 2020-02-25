import Route from "@ember/routing/route";
import { findWizard } from "wizard/models/wizard";

export default Route.extend({
  model() {
    return findWizard();
  },

  actions: {
    refresh() {
      this.refresh();
    }
  }
});
