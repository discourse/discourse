import {
  googleTagManagerPageChanged,
  resetPageTracking,
  startPageTracking,
} from "discourse/lib/page-tracker";
import { resetAjax, trackNextAjaxAsPageview } from "discourse/lib/ajax";

export default {
  after: "inject-objects",

  initialize(owner) {
    // Tell our AJAX system to track a page transition
    const router = owner.lookup("router:main");
    router.on("routeWillChange", this.handleRouteWillChange);

    let appEvents = owner.lookup("service:app-events");
    let documentTitle = owner.lookup("service:document-title");

    startPageTracking(router, appEvents, documentTitle);

    // Out of the box, Discourse tries to track google analytics
    // if it is present
    if (typeof window._gaq !== "undefined") {
      appEvents.on("page:changed", (data) => {
        if (!data.replacedOnlyQueryParams) {
          window._gaq.push(["_set", "title", data.title]);
          window._gaq.push(["_trackPageview", data.url]);
        }
      });
      return;
    }

    // Use Universal Analytics v3 if it is present
    if (
      typeof window.ga !== "undefined" &&
      typeof window.gtag === "undefined"
    ) {
      appEvents.on("page:changed", (data) => {
        if (!data.replacedOnlyQueryParams) {
          window.ga("send", "pageview", { page: data.url, title: data.title });
        }
      });
    }

    // And Universal Analytics v4 if we're upgraded
    if (typeof window.gtag !== "undefined") {
      appEvents.on("page:changed", (data) => {
        if (!data.replacedOnlyQueryParams) {
          window.gtag("event", "page_view", {
            page_location: data.url,
            page_title: data.title,
          });
        }
      });
    }

    // Google Tag Manager too
    if (typeof window.dataLayer !== "undefined") {
      appEvents.on("page:changed", (data) => {
        if (!data.replacedOnlyQueryParams) {
          googleTagManagerPageChanged(data);
        }
      });
    }
  },

  handleRouteWillChange(transition) {
    // transition.from will be null on initial boot transition, which is already tracked as a pageview via the HTML request
    if (!transition.from) {
      return;
    }

    // Ignore intermediate transitions (e.g. loading substates)
    if (transition.isIntermediate) {
      return;
    }

    trackNextAjaxAsPageview();
  },

  teardown() {
    resetPageTracking();
    resetAjax();
  },
};
