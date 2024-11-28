import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";

@tagName("")
export default class ComposerToggles extends Component {
  @discourseComputed("composeState")
  toggleTitle(composeState) {
    return composeState === "draft" || composeState === "saving"
      ? "composer.abandon"
      : "composer.collapse";
  }

  @discourseComputed("showToolbar")
  toggleToolbarTitle(showToolbar) {
    return showToolbar ? "composer.hide_toolbar" : "composer.show_toolbar";
  }

  @discourseComputed("composeState")
  fullscreenTitle(composeState) {
    return composeState === "draft"
      ? "composer.open"
      : composeState === "fullscreen"
      ? "composer.exit_fullscreen"
      : "composer.enter_fullscreen";
  }

  @discourseComputed("composeState")
  toggleIcon(composeState) {
    return composeState === "draft" || composeState === "saving"
      ? "xmark"
      : "angles-down";
  }

  @discourseComputed("composeState")
  fullscreenIcon(composeState) {
    return composeState === "draft"
      ? "angles-up"
      : composeState === "fullscreen"
      ? "discourse-compress"
      : "discourse-expand";
  }

  @discourseComputed("disableTextarea")
  showFullScreenButton(disableTextarea) {
    if (this.site.mobileView) {
      return false;
    }
    return !disableTextarea;
  }
}
