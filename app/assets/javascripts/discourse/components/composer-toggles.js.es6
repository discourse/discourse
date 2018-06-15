import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "",

  @computed("composeState")
  title(composeState) {
    if (composeState === "draft" || composeState === "saving") {
      return "composer.abandon";
    }
    return "composer.collapse";
  },

  @computed("composeState")
  toggleIcon(composeState) {
    if (composeState === "draft" || composeState === "saving") {
      return "times";
    }
    return "chevron-down";
  }
});
