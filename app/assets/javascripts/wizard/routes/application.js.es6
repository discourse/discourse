import { findWizard } from "wizard/models/wizard";

export default Ember.Route.extend({
  model() {
    return findWizard();
  }
});
