import { cleanDOM } from "discourse/lib/clean-dom";
import {
  startPageTracking,
  googleTagManagerPageChanged
} from "discourse/lib/page-tracker";
import { viewTrackingRequired } from "discourse/lib/ajax";

export default {
  name: "page-tracking",
  after: "inject-objects",

  initialize(container) {
    // Tell our AJAX system to track a page transition
    const router = container.lookup("router:main");
    router.on("willTransition", viewTrackingRequired);
    router.on("didTransition", cleanDOM);

    let appEvents = container.lookup("app-events:main");
    startPageTracking(router, appEvents);

    // Out of the box, Discourse tries to track google analytics
    // if it is present
    if (typeof window._gaq !== "undefined") {
      appEvents.on("page:changed", data => {
        window._gaq.push(["_set", "title", data.title]);
        window._gaq.push(["_trackPageview", data.url]);
      });
      return;
    }

    // Also use Universal Analytics if it is present
    if (typeof window.ga !== "undefined") {
      appEvents.on("page:changed", data => {
        window.ga("send", "pageview", { page: data.url, title: data.title });
      });
    }

    // And Google Tag Manager too
    if (typeof window.dataLayer !== "undefined") {
      appEvents.on("page:changed", googleTagManagerPageChanged);
    }
  }
};
