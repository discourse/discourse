export default Ember.Component.extend({
  didInsertElement() {
    this._super();
    this.$("input")
      .select()
      .focus();
  }
});
