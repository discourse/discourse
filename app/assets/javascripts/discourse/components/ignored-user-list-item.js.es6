export default Ember.Component.extend({
  tagName: "div",
  items: null,
  actions: {
    removeItem(item) {
      this.send("removeItem", item);
    }
  }
});
