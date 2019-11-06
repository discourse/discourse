import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  tagName: "",

  @computed("composeState")
  toggleTitle(composeState) {
    return composeState === "draft" || composeState === "saving"
      ? "composer.abandon"
      : "composer.collapse";
  },

  @computed("composeState")
  fullscreenTitle(composeState) {
    return composeState === "draft"
      ? "composer.open"
      : composeState === "fullscreen"
      ? "composer.exit_fullscreen"
      : "composer.enter_fullscreen";
  },

  @computed("composeState")
  toggleIcon(composeState) {
    return composeState === "draft" || composeState === "saving"
      ? "times"
      : "chevron-down";
  },

  @computed("composeState")
  fullscreenIcon(composeState) {
    return composeState === "draft"
      ? "chevron-up"
      : composeState === "fullscreen"
      ? "discourse-compress"
      : "discourse-expand";
  }
});
