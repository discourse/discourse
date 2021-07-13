import Component from "@ember/component";
export default Component.extend({
  tagName: "",
  actions: {
    share: function (source) {
      this.action(source);
    },
  },
});
