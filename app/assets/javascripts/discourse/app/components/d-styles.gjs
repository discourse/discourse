import Component from "@glimmer/component";
import { service } from "@ember/service";
import { getURLWithCDN } from "discourse/lib/get-url";

export default class DStyles extends Component {
  @service session;
  @service site;

  get categoryColors() {
    return [
      ":root {",
      ...this.site.categories.map(
        (category) => `--category-${category.id}-color: #${category.color};`
      ),
      "}",
    ].join("\n");
  }

  get categoryBackgrounds() {
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

    return css.join("\n");
  }

  get categoryBadges() {
    const css = [];

    this.site.categories.forEach((category) => {
      css.push(
        `.badge-category[data-category-id="${category.id}"] { ` +
          `--category-badge-color: var(--category-${category.id}-color); ` +
          `--category-badge-text-color: #${category.text_color}; ` +
          `}`
      );

      if (category.isParent) {
        css.push(
          `.badge-category[data-parent-category-id="${category.id}"] { ` +
            `--parent-category-badge-color: var(--category-${category.id}-color); ` +
            `}`
        );
      }
    });

    return css.join("\n");
  }

  <template>
    {{! template-lint-disable no-forbidden-elements }}
    <style id="d-styles">
      {{#if this.site.categories}}
        {{this.categoryColors}}
        {{this.categoryBackgrounds}}
        {{this.categoryBadges}}
      {{/if}}
    </style>
  </template>
}
