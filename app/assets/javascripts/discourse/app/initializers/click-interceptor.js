import DiscourseURL from "discourse/lib/url";
import interceptClick from "discourse/lib/intercept-click";

function interceptClickOnLinks(event) {
  if (event.target.tagName === "A") {
    interceptClick(event);
  }
}

export default {
  name: "click-interceptor",

  initialize() {
    window.addEventListener("click", interceptClickOnLinks);
    window.addEventListener("hashchange", this.hashChanged);
  },

  hashChanged() {
    DiscourseURL.routeTo(document.location.hash);
  },

  teardown() {
    window.removeEventListener("click", interceptClickOnLinks);
    window.removeEventListener("hashchange", this.hashChanged);
  },
};
