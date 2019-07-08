export default Ember.Component.extend({
  didInsertElement() {
    this._super(...arguments);
    $(this.element.querySelector("input"))
      .select()
      .focus();
  }
});
