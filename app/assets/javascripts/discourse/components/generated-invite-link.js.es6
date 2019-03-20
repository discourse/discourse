export default Ember.Component.extend({
  didInsertElement() {
    this._super(...arguments);
    this.$("input")
      .select()
      .focus();
  }
});
