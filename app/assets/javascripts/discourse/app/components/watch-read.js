import { bind } from "discourse-common/utils/decorators";
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
      this._markRead();
      window.addEventListener("resize", this._markRead, false);
      window.addEventListener("scroll", this._markRead, false);
    }
  },

  willDestroyElement() {
    this._super(...arguments);

    window.removeEventListener("resize", this._markRead);
    window.removeEventListener("scroll", this._markRead);
  },

  @bind
  _markRead() {
    const faqUnread = !this.currentUser.read_faq;

    if (
      faqUnread &&
      isElementInViewport(document.querySelector(".contents p:last-child"))
    ) {
      this.action();
    }
  },
});
