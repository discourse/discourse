export default Ember.Component.extend({
  classNames: "select-box-collection",

  actions: {
    onClearSelection() {
      this.sendAction("onClearSelection");
    }
  }
});
