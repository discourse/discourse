export default Ember.Component.extend({
  layoutName: "discourse-common/templates/components/select-box/select-box-collection",

  classNames: "select-box-collection",

  actions: {
    onClearSelection() {
      this.sendAction("onClearSelection");
    }
  }
});
