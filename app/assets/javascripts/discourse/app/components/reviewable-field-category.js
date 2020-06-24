import Component from "@ember/component";

export default Component.extend({
  actions: {
    onChange(category) {
      this.set("value", category);
      this.categoryChanged && this.categoryChanged(category);
    }
  }
});
