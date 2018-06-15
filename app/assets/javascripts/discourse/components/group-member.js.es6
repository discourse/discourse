export default Ember.Component.extend({
  classNames: ["item"],

  actions: {
    remove() {
      this.sendAction("removeAction", this.get("member"));
    }
  }
});
