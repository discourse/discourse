import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import discourseComputed, { observes } from "discourse-common/utils/decorators";

export default Component.extend({
  showSelector: true,
  shouldHide: false,
  defaultUsernameCount: 0,

  didInsertElement() {
    this._super(...arguments);

    if (this.focusTarget === "usernames") {
      $(this.element.querySelector("input")).putCursorAtEnd();
    }
  },

  @observes("usernames")
  _checkWidth() {
    let width = 0;
    const $acWrap = $(this.element).find(".ac-wrap");
    const limit = $acWrap.width();
    this.set("defaultUsernameCount", 0);

    $acWrap
      .find(".item")
      .toArray()
      .forEach(item => {
        width += $(item).outerWidth(true);
        const result = width < limit;

        if (result) this.incrementProperty("defaultUsernameCount");
        return result;
      });

    if (width >= limit) {
      this.set("shouldHide", true);
    } else {
      this.set("shouldHide", false);
    }
  },

  @observes("shouldHide")
  _setFocus() {
    const selector =
      "#reply-control #reply-title, #reply-control .d-editor-input";

    if (this.shouldHide) {
      $(selector).on("focus.composer-user-selector", () => {
        this.set("showSelector", false);
        this.appEvents.trigger("composer:resize");
      });
    } else {
      $(selector).off("focus.composer-user-selector");
    }
  },

  @discourseComputed("usernames")
  splitUsernames(usernames) {
    return usernames.split(",");
  },

  @discourseComputed("splitUsernames", "defaultUsernameCount")
  limitedUsernames(splitUsernames, count) {
    return splitUsernames.slice(0, count).join(", ");
  },

  @discourseComputed("splitUsernames", "defaultUsernameCount")
  hiddenUsersCount(splitUsernames, count) {
    return `${splitUsernames.length - count} ${I18n.t("more")}`;
  },

  actions: {
    toggleSelector() {
      this.set("showSelector", true);

      schedule("afterRender", () => {
        $(this.element)
          .find("input")
          .focus();
      });
    },

    triggerResize() {
      this.appEvents.trigger("composer:resize");
      const $this = $(this.element).find(".ac-wrap");
      if ($this.height() >= 150) $this.scrollTop($this.height());
    }
  }
});
