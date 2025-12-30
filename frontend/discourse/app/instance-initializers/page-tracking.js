import {
  resetAjax,
  trackNextAjaxAsPageview,
  trackNextAjaxAsTopicView,
} from "discourse/lib/ajax";
import {
  googleTagManagerPageChanged,
  resetPageTracking,
  startPageTracking,
} from "discourse/lib/page-tracker";
import { sendDeferredPageview } from "./message-bus";

let _emberRouter = null; // router:main - has _routerMicrolib for recognizer
let _routerService = null; // service:router - has urlFor

/**
 * Build URL from a RouteInfo object (transition.to)
 * @param {RouteInfo} routeInfo - The target route info (transition.to)
 * @returns {{ path: string, queryString: string|null }} The generated URL parts
 */
function buildUrlFromRouteInfo(routeInfo) {
  if (!_emberRouter || !_routerService || !routeInfo?.name) {
    return { path: null, queryString: null };
  }

  const routeName = routeInfo.name;

  // Collect all params from the route chain (child to root)
  const allParams = {};
  let current = routeInfo;
  while (current) {
    Object.assign(allParams, current.params);
    current = current.parent;
  }

  // Get the expected param names in order from the recognizer
  // eslint-disable-next-line ember/no-private-routing-service
  const recognizer = _emberRouter._routerMicrolib?.recognizer;
  const handlers = recognizer?.names[routeName]?.handlers || [];

  // Extract param values in order
  const orderedParams = [];
  for (const handler of handlers) {
    for (const paramName of handler.names || []) {
      if (allParams[paramName] !== undefined) {
        orderedParams.push(allParams[paramName]);
      }
    }
  }

  // Build query string from routeInfo.queryParams
  const queryParams = routeInfo.queryParams || {};
  let queryString = null;
  const queryEntries = Object.entries(queryParams).filter(
    ([, v]) => v !== null && v !== undefined && v !== ""
  );
  if (queryEntries.length > 0) {
    queryString = queryEntries
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join("&");
  }

  try {
    // Use routerService.urlFor with ordered params (no queryParams - we handle separately)
    const path = _routerService.urlFor(routeName, ...orderedParams);
    return { path, queryString };
  } catch {
    // Fallback if urlFor fails
    return { path: null, queryString };
  }
}

export default {
  after: "inject-objects",
  before: "message-bus",

  initialize(owner) {
    const isErrorPage =
      document.querySelector("meta#discourse-error")?.dataset.discourseError ===
      "true";
    if (!isErrorPage) {
      sendDeferredPageview();
    }

    // Tell our AJAX system to track a page transition
    // eslint-disable-next-line ember/no-private-routing-service
    _emberRouter = owner.lookup("router:main");
    _routerService = owner.lookup("service:router");
    _emberRouter.on("routeWillChange", this.handleRouteWillChange);

    let appEvents = owner.lookup("service:app-events");
    let documentTitle = owner.lookup("service:document-title");

    startPageTracking(_emberRouter, appEvents, documentTitle);

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

    // Build the target URL from the RouteInfo
    // This works for both URL-based and route-name-based transitions
    const { path: targetPath, queryString: targetQueryString } =
      buildUrlFromRouteInfo(transition.to);

    // Track this navigation with the correct URL data
    trackNextAjaxAsPageview({
      routeName: transition.to?.name,
      path: targetPath,
      queryString: targetQueryString,
    });

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
    _emberRouter = null;
    _routerService = null;
  },
};
