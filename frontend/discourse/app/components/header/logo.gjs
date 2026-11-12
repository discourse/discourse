import Component from "@glimmer/component";
import { service } from "@ember/service";
import getURL from "discourse/lib/get-url";

export default class Logo extends Component {
  @service interfaceColor;

  get darkMediaQuery() {
    if (this.interfaceColor.darkModeForced) {
      return "all";
    } else if (this.interfaceColor.lightModeForced) {
      return "none";
    } else {
      return "(prefers-color-scheme: dark)";
    }
  }

  <template>
    {{#if (and @darkUrl (neq @url @darkUrl))}}
      <picture>
        <source media={{this.darkMediaQuery}} srcset={{getURL @darkUrl}} />
        <img
          alt={{@title}}
          class={{@key}}
          id="site-logo"
          src={{getURL @url}}
          width={{if (eq @key "logo-small") "36"}}
        />
      </picture>
    {{else}}
      <img
        alt={{@title}}
        class={{@key}}
        id="site-logo"
        src={{getURL @url}}
        width={{if (eq @key "logo-small") "36"}}
      />
    {{/if}}
  </template>
}
