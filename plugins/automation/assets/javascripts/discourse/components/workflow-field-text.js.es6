export default Ember.Component.extend({
  actions: {
    onChange(event) {
      this.onChange(event.target.value);
    }
  }
});
