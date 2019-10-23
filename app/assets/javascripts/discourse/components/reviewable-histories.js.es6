import Component from "@ember/component";
export default Component.extend({
  filteredHistories: Ember.computed.filterBy("histories", "created", false)
});
