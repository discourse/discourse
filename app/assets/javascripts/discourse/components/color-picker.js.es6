export default Ember.Component.extend({
  classNames: "colors-container",

  actions: {
    selectColor(color) {
      this.set("value", color);
    }
  }
});
