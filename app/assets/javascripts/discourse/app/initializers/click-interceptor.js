import DiscourseURL from "discourse/lib/url";
import interceptClick from "discourse/lib/intercept-click";

export default {
  name: "click-interceptor",
  initialize() {
    $("#main").on("click.discourse", "a", interceptClick);
    window.addEventListener("hashchange", this.hashChanged);
  },

  hashChanged() {
    DiscourseURL.routeTo(document.location.hash);
  },

  teardown() {
    $("#main").off("click.discourse", "a", interceptClick);
    window.removeEventListener("hashchange", this.hashChanged);
  },
};
