import interceptClick from "discourse/lib/intercept-click";
import DiscourseURL from "discourse/lib/url";

export default {
  initialize(owner) {
    this.selector = owner.rootElement;
    document
      .querySelector(this.selector)
      .addEventListener("click", interceptClick);
    window.addEventListener("hashchange", this.hashChanged);
  },

  hashChanged() {
    DiscourseURL.routeTo(document.location.hash);
  },

  teardown() {
    document
      .querySelector(this.selector)
      .removeEventListener("click", interceptClick);
    window.removeEventListener("hashchange", this.hashChanged);
  },
};
