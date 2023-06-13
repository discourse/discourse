import DiscourseURL from "discourse/lib/url";
import interceptClick from "discourse/lib/intercept-click";

export default {
  name: "click-interceptor",
  initialize(container, app) {
    this.rootElement = document.querySelector(app.rootElement);
    this.rootElement.addEventListener("click", this.interceptClick);
    window.addEventListener("hashchange", this.hashChanged);
  },

  interceptClick(event) {
    if (event.currentTarget.tagName !== "A") {
      return;
    }

    return interceptClick(event);
  },

  hashChanged() {
    DiscourseURL.routeTo(document.location.hash);
  },

  teardown() {
    this.rootElement.removeEventListener("click", this.interceptClick);
    window.removeEventListener("hashchange", this.hashChanged);
  },
};
