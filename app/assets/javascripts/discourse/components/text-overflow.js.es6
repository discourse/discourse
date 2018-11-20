export default Ember.Component.extend({
  didInsertElement() {
    this._super();
    Ember.run.next(null, () => {
      this.$()
        .find("hr")
        .remove();
      this.$().ellipsis();
    });
  }
});
