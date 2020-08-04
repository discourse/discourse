import Component from "@ember/component";
export default Component.extend({
  tagName: "div",
  items: null,
  actions: {
    removeIgnoredUser(item) {
      this.onRemoveIgnoredUser(item);
    }
  }
});
