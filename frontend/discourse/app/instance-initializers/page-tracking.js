import { sendBeaconPageview } from "discourse/lib/beacon-pageview";
import EmbedMode from "discourse/lib/embed-mode";
import {
  googleTagManagerPageChanged,
  resetPageTracking,
  startPageTracking,
} from "discourse/lib/page-tracker";

let _preNavigationUrl = null;
let _isErrorPage = false;

export default {
  after: "inject-objects",
  before: "message-bus",

  initialize(owner) {
    // eslint-disable-next-line ember/no-private-routing-service
    const router = owner.lookup("router:main");
    _isErrorPage =
      document.querySelector("meta#discourse-error")?.dataset.discourseError ===
      "true";
    router.on("routeDidChange", this.handleRouteDidChange);

    let appEvents = owner.lookup("service:app-events");
    let documentTitle = owner.lookup("service:document-title");

    startPageTracking(router, appEvents, documentTitle);

    const isEmbedded = EmbedMode.enabled;

    // Out of the box, Discourse tries to track google analytics
    // if it is present
    if (typeof window._gaq !== "undefined") {
      appEvents.on("page:changed", (data) => {
        if (!data.replacedOnlyQueryParams) {
          if (isEmbedded) {
            window._gaq.push(["_setCustomVar", 1, "embed_mode", "true", 3]);
          }
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
          let gaFields = { page: data.url, title: data.title };
          if (isEmbedded) {
            gaFields.dimension1 = "embed";
          }
          window.ga("send", "pageview", gaFields);
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
            embed_mode: isEmbedded || undefined,
          });
        }
      });
    }

    // Google Tag Manager too
    if (typeof window.dataLayer !== "undefined") {
      appEvents.on("page:changed", (data) => {
        if (!data.replacedOnlyQueryParams) {
          if (isEmbedded) {
            data = Object.assign({}, data, { embed_mode: true });
          }
          googleTagManagerPageChanged(data);
        }
      });
    }
  },

  handleRouteDidChange(transition) {
    if (transition.isAborted) {
      return;
    }

    if (_isErrorPage && !transition.from) {
      _preNavigationUrl = window.location.href;
      return;
    }

    const trackingSessionId = document.querySelector(
      "meta[name=discourse-track-view-session-id]"
    )?.content;
    const referrerUrl = transition.from
      ? _preNavigationUrl
      : document.referrer.length
        ? document.referrer
        : null;

    let topicId;
    if (
      transition.to.name === "topic.fromParamsNear" ||
      transition.to.name === "topic.fromParams"
    ) {
      topicId = transition.to.parent.params.id;
    }

    sendBeaconPageview({
      sessionId: trackingSessionId,
      url: window.location.href,
      referrer: referrerUrl,
      topicId,
      navigation: !!transition.from,
    });

    _preNavigationUrl = window.location.href;
  },

  teardown() {
    resetPageTracking();
  },
};
