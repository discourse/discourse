import { getURLWithCDN } from "discourse-common/lib/get-url";

export default {
  after: "register-hashtag-types",

  initialize(owner) {
    this.session = owner.lookup("service:session");
    this.site = owner.lookup("service:site");

    if (!this.site.categories?.length) {
      return;
    }

    const css = [];
    const darkCss = [];

    this.site.categories.forEach((category) => {
      const lightUrl = category.uploaded_background?.url;
      const darkUrl =
        this.session.defaultColorSchemeIsDark || this.session.darkModeAvailable
          ? category.uploaded_background_dark?.url
          : null;
      const defaultUrl =
        darkUrl && this.session.defaultColorSchemeIsDark ? darkUrl : lightUrl;

      if (defaultUrl) {
        const url = getURLWithCDN(defaultUrl);
        css.push(
          `body.category-${category.fullSlug} { background-image: url(${url}); }`
        );
      }

      if (darkUrl && defaultUrl !== darkUrl) {
        const url = getURLWithCDN(darkUrl);
        darkCss.push(
          `body.category-${category.fullSlug} { background-image: url(${url}); }`
        );
      }
    });

    if (darkCss.length > 0) {
      css.push("@media (prefers-color-scheme: dark) {", ...darkCss, "}");
    }

    const cssTag = document.createElement("style");
    cssTag.type = "text/css";
    cssTag.id = "category-background-css-generator";
    cssTag.innerHTML = css.join("\n");
    document.head.appendChild(cssTag);
  },

  teardown() {
    document.querySelector("#category-background-css-generator")?.remove();
  },
};
