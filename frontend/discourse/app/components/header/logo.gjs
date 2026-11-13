import Component from "@glimmer/component";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";

export default class Logo extends Component {
  @service interfaceColor;
  @service siteSettings;

  get darkMediaQuery() {
    if (this.interfaceColor.darkModeForced) {
      return "all";
    } else if (this.interfaceColor.lightModeForced) {
      return "none";
    } else {
      return "(prefers-color-scheme: dark)";
    }
  }

  get dimensions() {
    return this.siteSettings.site_logo_dimensions?.[this.args.url];
  }

  get darkDimensions() {
    return this.siteSettings.site_logo_dimensions?.[this.args.darkUrl];
  }

  <template>
    {{#if (and @darkUrl (neq @url @darkUrl))}}
      <picture>
        <source
          height={{this.darkDimensions.height}}
          media={{this.darkMediaQuery}}
          srcset={{getURL @darkUrl}}
          width={{this.darkDimensions.width}}
        />
        <img
          alt={{@title}}
          class={{@key}}
          height={{this.dimensions.height}}
          id="site-logo"
          src={{getURL @url}}
          width={{or this.dimensions.width (if (eq @key "logo-small") "36")}}
        />
      </picture>
    {{else}}
      <img
        alt={{@title}}
        class={{@key}}
        height={{this.dimensions.height}}
        id="site-logo"
        src={{getURL @url}}
        width={{or this.dimensions.width (if (eq @key "logo-small") "36")}}
      />
    {{/if}}
  </template>
}
