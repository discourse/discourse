import { getAbsoluteURL } from "discourse/lib/get-url";
import { getCanonicalUrl } from "discourse/lib/url";

export default {
  initialize(owner) {
    // workaround for Safari on iOS 14.3
    // seems it has started using opengraph tags when sharing
    const ogTitle = document.querySelector("meta[property='og:title']");
    const ogUrl = document.querySelector("meta[property='og:url']");
    const twitterTitle = document.querySelector("meta[name='twitter:title']");
    const twitterUrl = document.querySelector("meta[name='twitter:url']");

    // workaround for mobile Chrome, which uses the canonical url when sharing
    const canonicalUrl = document.querySelector("link[rel='canonical']");

    const appEvents = owner.lookup("service:app-events");
    appEvents.on("page:changed", ({ title, url }) => {
      const absoluteUrl = getAbsoluteURL(url);

      ogTitle?.setAttribute("content", title);
      ogUrl?.setAttribute("content", absoluteUrl);
      twitterTitle?.setAttribute("content", title);
      twitterUrl?.setAttribute("content", absoluteUrl);

      if (canonicalUrl) {
        canonicalUrl.setAttribute("href", getCanonicalUrl(absoluteUrl));
      }
    });
  },
};
