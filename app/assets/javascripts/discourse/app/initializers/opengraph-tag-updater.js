import { getAbsoluteURL } from "discourse-common/lib/get-url";

export default {
  name: "opengraph-tag-updater",

  initialize(container) {
    // workaround for Safari on iOS 14.3
    // seems it has started using opengraph tags when sharing
    const ogTitle = document.querySelector("meta[property='og:title']");
    const ogUrl = document.querySelector("meta[property='og:url']");
    const twitterTitle = document.querySelector(
      "meta[property='twitter:title']"
    );
    const twitterUrl = document.querySelector("meta[property='twitter:url']");

    if (!ogTitle || !ogUrl || !twitterTitle || !twitterUrl) {
      return;
    }

    const appEvents = container.lookup("service:app-events");
    appEvents.on("page:changed", ({ title, url }) => {
      ogTitle.setAttribute("content", title);
      ogUrl.setAttribute("content", getAbsoluteURL(url));
      twitterTitle.setAttribute("content", title);
      twitterUrl.setAttribute("content", getAbsoluteURL(url));
    });
  },
};
