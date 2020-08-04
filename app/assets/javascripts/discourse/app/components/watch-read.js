import Component from "@ember/component";
import isElementInViewport from "discourse/lib/is-element-in-viewport";

export default Component.extend({
  didInsertElement() {
    this._super(...arguments);
    const currentUser = this.currentUser;
    if (!currentUser) {
      return;
    }

    const path = this.path;
    if (path === "faq" || path === "guidelines") {
      $(window).on("load.faq resize.faq scroll.faq", () => {
        const faqUnread = !currentUser.get("read_faq");
        if (faqUnread && isElementInViewport($(".contents p").last())) {
          this.action();
        }
      });
    }
  },

  willDestroyElement() {
    this._super(...arguments);
    $(window).off("load.faq resize.faq scroll.faq");
  }
});
