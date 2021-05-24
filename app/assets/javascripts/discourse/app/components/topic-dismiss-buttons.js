import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import { later } from "@ember/runloop";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import I18n from "I18n";
import Component from "@ember/component";

export default Component.extend({
  tagName: "",
  classNames: ["topic-dismiss-buttons"],

  position: null,
  selectedTopics: null,
  model: null,

  @discourseComputed("position")
  containerClass(position) {
    return `dismiss-container-${position}`;
  },

  @discourseComputed("position")
  dismissReadId(position) {
    return `dismiss-topics-${position}`;
  },

  @discourseComputed("position")
  dismissNewId(position) {
    return `dismiss-new-${position}`;
  },

  @discourseComputed(
    "position",
    "isOtherDismissUnreadButtonVisible",
    "isOtherDismissNewButtonVisible"
  )
  showBasedOnPosition(
    position,
    isOtherDismissUnreadButtonVisible,
    isOtherDismissNewButtonVisible
  ) {
    if (position !== "top") {
      return true;
    }

    return !(
      isOtherDismissUnreadButtonVisible || isOtherDismissNewButtonVisible
    );
  },

  @discourseComputed("selectedTopics.length")
  dismissLabel(selectedTopicCount) {
    if (selectedTopicCount === 0) {
      return I18n.t("topics.bulk.dismiss_button");
    }
    return I18n.t("topics.bulk.dismiss_button_with_selected", {
      count: selectedTopicCount,
    });
  },

  @discourseComputed("selectedTopics.length")
  dismissNewLabel(selectedTopicCount) {
    if (selectedTopicCount === 0) {
      return I18n.t("topics.bulk.dismiss_new");
    }
    return I18n.t("topics.bulk.dismiss_new_with_selected", {
      count: selectedTopicCount,
    });
  },

  // we want to only render the Dismiss... button at the top of the
  // page if the user cannot see the bottom Dismiss... button based on their
  // viewport, or if too many topics fill the page
  @on("didInsertElement")
  _determineOtherDismissVisibility() {
    later(() => {
      if (this.position === "top") {
        this.set(
          "isOtherDismissUnreadButtonVisible",
          isElementInViewport(document.getElementById("dismiss-topics-bottom"))
        );
        this.set(
          "isOtherDismissNewButtonVisible",
          isElementInViewport(document.getElementById("dismiss-new-bottom"))
        );
      } else {
        this.set("isOtherDismissUnreadButtonVisible", true);
        this.set("isOtherDismissNewButtonVisible", true);
      }
    });
  },

  @action
  dismissReadPosts() {
    let dismissTitle = "topics.bulk.dismiss_read";
    if (this.selectedTopics.length > 0) {
      dismissTitle = "topics.bulk.dismiss_read_with_selected";
    }
    showModal("dismiss-read", {
      titleTranslated: I18n.t(dismissTitle, {
        count: this.selectedTopics.length,
      }),
    });
  },
});
