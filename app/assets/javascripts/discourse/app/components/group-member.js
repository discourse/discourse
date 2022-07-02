import Component from "@ember/component";
export default Component.extend({
  tagName: "",

  actions: {
    remove() {
      this.removeAction(this.member);
    },
  },
});
