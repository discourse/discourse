export default Ember.Component.extend({
  layoutName: "select-box-kit/templates/components/select-box-kit/select-box-kit-collection",

  classNames: "collection",

  tagName: "ul",

  actions: {
    onClearSelection() {
      this.sendAction("onClearSelection");
    }
  }
});
