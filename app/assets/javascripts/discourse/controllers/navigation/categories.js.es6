import NavigationDefaultController from "discourse/controllers/navigation/default";
import computed from "ember-addons/ember-computed-decorators";

export default NavigationDefaultController.extend({
  discoveryCategories: Ember.inject.controller("discovery/categories"),

  @computed("discoveryCategories.model", "discoveryCategories.model.draft")
  draft() {
    return this.get("discoveryCategories.model.draft");
  }
});
