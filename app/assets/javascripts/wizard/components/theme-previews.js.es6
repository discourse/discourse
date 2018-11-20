export default Ember.Component.extend({
  actions: {
    changed(value) {
      this.set("field.value", value);
    }
  }
});
