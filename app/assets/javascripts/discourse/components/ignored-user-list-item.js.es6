export default Ember.Component.extend({
  tagName: "div",
  items: null,
  actions: {
    removeIgnoredUser(item) {
      this.onRemoveIgnoredUser(item);
    }
  }
});
