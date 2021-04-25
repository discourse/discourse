import Component from "@ember/component";

export default Component.extend({
  actions: {
    showDetails() {
      this.set("showDetails", true);
    },
  },
});
