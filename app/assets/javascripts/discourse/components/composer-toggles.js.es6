import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  tagName: "",

  @discourseComputed("composeState")
  toggleTitle(composeState) {
    return composeState === "draft" || composeState === "saving"
      ? "composer.abandon"
      : "composer.collapse";
  },

  @discourseComputed("composeState")
  fullscreenTitle(composeState) {
    return composeState === "draft"
      ? "composer.open"
      : composeState === "fullscreen"
      ? "composer.exit_fullscreen"
      : "composer.enter_fullscreen";
  },

  @discourseComputed("composeState")
  toggleIcon(composeState) {
    return composeState === "draft" || composeState === "saving"
      ? "times"
      : "chevron-down";
  },

  @discourseComputed("composeState")
  fullscreenIcon(composeState) {
    return composeState === "draft"
      ? "chevron-up"
      : composeState === "fullscreen"
      ? "discourse-compress"
      : "discourse-expand";
  }
});
