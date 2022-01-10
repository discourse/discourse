import DiscourseURL from "discourse/lib/url";
import interceptClick from "discourse/lib/intercept-click";

export default {
  name: "click-interceptor",
  initialize(container, app) {
    this.selector = app.rootElement;
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
