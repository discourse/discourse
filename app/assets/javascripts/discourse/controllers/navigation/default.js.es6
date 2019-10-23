import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  discovery: Ember.inject.controller(),
  discoveryTopics: Ember.inject.controller("discovery/topics"),

  @computed("discoveryTopics.model", "discoveryTopics.model.draft")
  draft: function() {
    return this.get("discoveryTopics.model.draft");
  }
});
