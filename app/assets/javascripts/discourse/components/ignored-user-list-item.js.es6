export default Ember.Component.extend({
  tagName: "div",
  router: Ember.inject.service(),
  items: null,
  actions: {
    removeItem(item) {
      this.get("onRemoveItem")(item);
    }
  }
});
