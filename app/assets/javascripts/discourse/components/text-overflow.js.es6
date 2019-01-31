export default Ember.Component.extend({
  didInsertElement() {
    this._super(...arguments);
    Ember.run.next(null, () => {
      this.$()
        .find("hr")
        .remove();
      this.$().ellipsis();
    });
  }
});
