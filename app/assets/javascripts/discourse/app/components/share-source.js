import Component from "@ember/component";
export default Component.extend({
  tagName: "",

  actions: {
    share(source) {
      this.action(source);
    },
  },
});
