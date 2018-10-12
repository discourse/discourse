import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "",

  @computed("composeState")
  toggleTitle(composeState) {
    if (composeState === "draft" || composeState === "saving") {
      return "composer.abandon";
    }
    return "composer.collapse";
  },

  @computed("composeState")
  fullscreenTitle(composeState) {
    if (composeState === "fullscreen") {
      return "composer.exit_fullscreen";
    }
    return "composer.enter_fullscreen";
  },

  @computed("composeState")
  toggleIcon(composeState) {
    if (composeState === "draft" || composeState === "saving") {
      return "times";
    }
    return "chevron-down";
  },

  @computed("composeState")
  fullscreenIcon(composeState) {
    if (composeState === "fullscreen") {
      return "compress";
    }
    return "expand";
  }
});
