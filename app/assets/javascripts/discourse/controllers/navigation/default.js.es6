export default Ember.Controller.extend({
  discovery: Ember.inject.controller(),
  discoveryTopics: Ember.inject.controller("discovery/topics"),

  draft: function() {
    return this.get("discoveryTopics.model.draft");
  }.property("discoveryTopics.model", "discoveryTopics.model.draft")
});
