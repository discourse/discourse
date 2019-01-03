export default Ember.Component.extend({
  filteredHistories: Ember.computed.filterBy("histories", "created", false)
});
