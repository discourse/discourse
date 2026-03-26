import { getOwner } from "@ember/owner";
import {
  resetAjax,
  trackNextAjaxAsPageview,
  trackNextAjaxAsTopicView,
} from "discourse/lib/ajax";
import { sendBeaconPageview } from "discourse/lib/beacon-pageview";
import { getAbsoluteURL } from "discourse/lib/get-url";
import {
  googleTagManagerPageChanged,
  resetPageTracking,
  startPageTracking,
} from "discourse/lib/page-tracker";
import { sendDeferredPageview } from "./message-bus";

export default {
  after: "inject-objects",
  before: "message-bus",

  initialize(owner) {
    const isErrorPage =
      document.querySelector("meta#discourse-error")?.dataset.discourseError ===
      "true";
    if (!isErrorPage) {
      const siteSettings = owner.lookup("service:site-settings");
      if (!siteSettings.use_beacon_for_browser_page_views) {
        sendDeferredPageview();
      }
    }

    // Tell our AJAX system to track a page transition
    // eslint-disable-next-line ember/no-private-routing-service
    const router = owner.lookup("router:main");
    router.on("routeWillChange", this.handleRouteWillChange);
    router.on("routeDidChange", this.handleRouteDidChange);

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

  handleRouteDidChange(transition) {
    const owner = getOwner(this);
    const siteSettings = owner.lookup("service:site-settings");

    if (!siteSettings.use_beacon_for_browser_page_views) {
      return;
    }

    const trackingSessionId = document.querySelector(
      "meta[name=discourse-track-view-session-id]"
    )?.content;
    let destinationUrl, referrerUrl;

    if (trackingSessionId) {
      if (transition.from) {
        const router = owner.lookup("service:router");
        let referrerPath;
        try {
          referrerPath = router.urlFor(
            transition.from.name,
            ...Object.values(transition.from.params)
          );
        } catch {}

        if (referrerPath) {
          referrerUrl = getAbsoluteURL(referrerPath);
        }
      } else {
        referrerUrl = document.referrer.length ? document.referrer : null;
      }
      destinationUrl = window.location.href;
    }

    let topicId;
    if (
      transition.to.name === "topic.fromParamsNear" ||
      transition.to.name === "topic.fromParams"
    ) {
      topicId = transition.to.parent.params.id;
    }

    sendBeaconPageview({
      sessionId: trackingSessionId,
      url: destinationUrl,
      referrer: referrerUrl,
      topicId,
    });
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

    const trackingSessionId = document.querySelector(
      "meta[name=discourse-track-view-session-id]"
    )?.content;
    let trackingUrl, trackingReferrer;

    if (trackingSessionId) {
      const owner = getOwner(this);
      const router = owner.lookup("service:router");
      let path = transition.intent?.url;
      if (!path) {
        try {
          path = router.urlFor(
            transition.to.name,
            ...Object.values(transition.to.params)
          );
        } catch {}
      }

      // The path may not be generated when there is a middle transition leading to another path.
      // That should not be counted as a page view.
      if (!path) {
        return;
      }
      trackingUrl = new URL(path, window.location.origin).href;
      trackingReferrer = window.location.href;
    }
    trackNextAjaxAsPageview(trackingSessionId, trackingUrl, trackingReferrer);

    if (
      transition.to.name === "topic.fromParamsNear" ||
      transition.to.name === "topic.fromParams"
    ) {
      trackNextAjaxAsTopicView(transition.to.parent.params.id);
    }
  },

  teardown() {
    resetPageTracking();
    resetAjax();
  },
};
