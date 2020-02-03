export default Ember.Component.extend({
  actions: {
    onChange(tags) {
      this.valueChanged &&
        this.valueChanged({
          target: {
            value: tags
          }
        });
    }
  }
});
