import DiscourseURL from "discourse/lib/url";
import interceptClick from "discourse/lib/intercept-click";

export default {
  name: "click-interceptor",
  initialize(container, app) {
    this.selector = app.rootElement;
    $(this.selector).on("click.discourse", "a", interceptClick);
    window.addEventListener("hashchange", this.hashChanged);
  },

  hashChanged() {
    DiscourseURL.routeTo(document.location.hash);
  },

  teardown() {
    $(this.selector).off("click.discourse", "a", interceptClick);
    window.removeEventListener("hashchange", this.hashChanged);
  },
};
