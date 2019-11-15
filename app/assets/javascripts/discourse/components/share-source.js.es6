import Component from "@ember/component";
export default Component.extend({
  classNameBindings: [":social-link"],

  actions: {
    share: function(source) {
      this.action(source);
    }
  }
});
