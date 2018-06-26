import NavigationDefaultController from "discourse/controllers/navigation/default";

export default NavigationDefaultController.extend({
  discoveryCategories: Ember.inject.controller("discovery/categories"),

  draft: function() {
    return this.get("discoveryCategories.model.draft");
  }.property("discoveryCategories.model", "discoveryCategories.model.draft")
});
