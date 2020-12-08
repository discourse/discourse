import DiscourseURL from "discourse/lib/url";
import interceptClick from "discourse/lib/intercept-click";

export default {
  name: "click-interceptor",
  initialize() {
    $("#main").on("click.discourse", "a", interceptClick);
    $(window).on("hashchange", () =>
      DiscourseURL.routeTo(document.location.hash)
    );
  },
};
