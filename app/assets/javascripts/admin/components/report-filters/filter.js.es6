export default Ember.Component.extend({
  actions: {
    onChange(value) {
      this.applyFilter(this.get("filter.id"), value);
    }
  }
});
