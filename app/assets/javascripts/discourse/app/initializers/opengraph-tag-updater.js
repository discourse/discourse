import { getAbsoluteURL } from "discourse-common/lib/get-url";

export default {
  name: "opengraph-tag-updater",

  initialize(container) {
    // workaround for Safari on iOS 14.3
    // seems it has started using opengraph tags when sharing
    let appEvents = container.lookup("service:app-events");
    const ogTitle = document.querySelector("meta[property='og:title']"),
      ogUrl = document.querySelector("meta[property='og:url']");

    if (ogTitle && ogUrl) {
      appEvents.on("page:changed", (data) => {
        ogTitle.setAttribute("content", data.title);
        ogUrl.setAttribute("content", getAbsoluteURL(data.url));
      });
    }
  },
};
