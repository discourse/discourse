import Route from "@ember/routing/route";
import { findWizard } from "wizard/models/wizard";
import { action } from "@ember/object";

export default Route.extend({
  model() {
    return findWizard();
  },

  @action
  refreshRoute() {
    this.refresh();
  },
});
