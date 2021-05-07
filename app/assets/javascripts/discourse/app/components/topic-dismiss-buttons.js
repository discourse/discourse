import { action } from "@ember/object";
import showModal from "discourse/lib/show-modal";
import { later } from "@ember/runloop";
import isElementInViewport from "discourse/lib/is-element-in-viewport";
import discourseComputed, { on } from "discourse-common/utils/decorators";
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

  @discourseComputed("model.filter", "model.topics.length")
  showDismissRead(filter, topicsLength) {
    return this._isFilterPage(filter, "unread") && topicsLength > 0;
  },

  @discourseComputed("model.filter", "model.topics.length")
  showResetNew(filter, topicsLength) {
    return this._isFilterPage(filter, "new") && topicsLength > 0;
  },

  @discourseComputed("position", "isOtherDismissButtonVisible", "model.filter")
  showBasedOnPosition(position, isOtherDismissButtonVisible, filter) {
    let positionShouldShow =
      position === "top" ? !isOtherDismissButtonVisible : true;

    return (
      (this._isFilterPage(filter, "new") ||
        this._isFilterPage(filter, "unread")) &&
      positionShouldShow
    );
  },

  // we want to only render the Dismiss... button at the top of the
  // page if the user cannot see the bottom Dismiss... button based on their
  // viewport, or if too many topics fill the page
  @on("didInsertElement")
  _determineOtherDismissVisibility() {
    later(() => {
      if (this.position === "top") {
        this.set(
          "isOtherDismissButtonVisible",
          isElementInViewport(document.getElementById("dismiss-topics-bottom"))
        );
      } else {
        this.set("isOtherDismissButtonVisible", true);
      }
    });
  },

  @action
  dismissReadPosts() {
    showModal("dismiss-read", { title: "topics.bulk.dismiss_read" });
  },

  _isFilterPage(filter, filterType) {
    if (!filter) {
      return false;
    }
    return filter.match(new RegExp(filterType + "$", "gi")) ? true : false;
  },
});
