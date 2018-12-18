export default Ember.Component.extend({
  classNames: ["item"],

  actions: {
    remove() {
      this.removeAction(this.get("member"));
    }
  }
});
