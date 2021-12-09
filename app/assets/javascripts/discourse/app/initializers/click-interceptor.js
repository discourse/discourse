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
    document
      .getElementById("main")
      .addEventListener("click", interceptClickOnLinks);
    window.addEventListener("hashchange", this.hashChanged);
  },

  hashChanged() {
    DiscourseURL.routeTo(document.location.hash);
  },

  teardown() {
    document
      .getElementById("main")
      .removeEventListener("click", interceptClickOnLinks);
    window.removeEventListener("hashchange", this.hashChanged);
  },
};
