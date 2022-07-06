import Component from "@ember/component";

export default Component.extend({
  tagName: "",

  actions: {
    onChange(category) {
      this.set("value", category);
      this.categoryChanged && this.categoryChanged(category);
    },
  },
});
