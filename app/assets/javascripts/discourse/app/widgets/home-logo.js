import DiscourseURL from "discourse/lib/url";
import Session from "discourse/models/session";
import { createWidget } from "discourse/widgets/widget";
import getURL from "discourse-common/lib/get-url";
import { h } from "@discourse/virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";
import { wantsNewWindow } from "discourse/lib/intercept-click";

export default createWidget("home-logo", {
  tagName: "div.title",

  settings: {
    href: getURL("/"),
  },

  buildClasses() {
    if (this.attrs.minimized) {
      return "title--minimized";
    }
  },

  href() {
    const href = this.settings.href;
    return typeof href === "function" ? href() : href;
  },

  logoUrl(opts = {}) {
    return this.logoResolver("logo", opts);
  },

  mobileLogoUrl(opts = {}) {
    return this.logoResolver("mobile_logo", opts);
  },

  smallLogoUrl(opts = {}) {
    return this.logoResolver("logo_small", opts);
  },

  logo() {
    const { siteSettings } = this,
      mobileView = this.site.mobileView;

    const darkModeOptions = Session.currentProp("darkModeAvailable")
      ? { dark: true }
      : {};

    const mobileLogoUrl = this.mobileLogoUrl(),
      mobileLogoUrlDark = this.mobileLogoUrl(darkModeOptions);

    const showMobileLogo = mobileView && mobileLogoUrl.length > 0;

    const logoUrl = this.logoUrl(),
      logoUrlDark = this.logoUrl(darkModeOptions);
    const title = siteSettings.title;

    if (this.attrs.minimized) {
      const logoSmallUrl = this.smallLogoUrl(),
        logoSmallUrlDark = this.smallLogoUrl(darkModeOptions);
      if (logoSmallUrl.length) {
        return this.logoElement(
          "logo-small",
          logoSmallUrl,
          title,
          logoSmallUrlDark
        );
      } else {
        return iconNode("home");
      }
    } else if (showMobileLogo) {
      return this.logoElement(
        "logo-mobile",
        mobileLogoUrl,
        title,
        mobileLogoUrlDark
      );
    } else if (logoUrl.length) {
      return this.logoElement("logo-big", logoUrl, title, logoUrlDark);
    } else {
      return h("h1#site-text-logo.text-logo", { key: "logo-text" }, title);
    }
  },

  logoResolver(name, opts = {}) {
    const { siteSettings } = this;

    // get alternative logos for browser dark dark mode switching
    if (opts.dark) {
      return siteSettings[`site_${name}_dark_url`];
    }

    // try dark logos first when color scheme is dark
    // this is independent of browser dark mode
    // hence the fallback to normal logos
    if (Session.currentProp("defaultColorSchemeIsDark")) {
      return (
        siteSettings[`site_${name}_dark_url`] ||
        siteSettings[`site_${name}_url`] ||
        ""
      );
    }

    return siteSettings[`site_${name}_url`] || "";
  },

  logoElement(key, url, title, darkUrl = null) {
    const attributes =
      key === "logo-small"
        ? { src: getURL(url), width: 36, alt: title }
        : { src: getURL(url), alt: title };

    const imgElement = h(`img#site-logo.${key}`, {
      key,
      attributes,
    });

    if (darkUrl && url !== darkUrl) {
      return h("picture", [
        h("source", {
          attributes: {
            srcset: getURL(darkUrl),
            media: "(prefers-color-scheme: dark)",
          },
        }),
        imgElement,
      ]);
    }

    return imgElement;
  },

  html() {
    return h(
      "a",
      { attributes: { href: this.href(), "data-auto-route": true } },
      this.logo()
    );
  },

  click(e) {
    if (wantsNewWindow(e)) {
      return false;
    }
    e.preventDefault();

    DiscourseURL.routeToTag(e.target.closest("a"));
    return false;
  },
});
