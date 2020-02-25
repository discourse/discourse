import Component from "@ember/component";
export default Component.extend({
  classNames: "colors-container",

  actions: {
    selectColor(color) {
      this.set("value", color);
    }
  }
});
