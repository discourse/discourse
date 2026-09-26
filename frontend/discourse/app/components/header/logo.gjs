import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import getURL from "discourse/lib/get-url";
import { and, eq, notEq } from "discourse/truth-helpers";
import InterfaceColorService from "discourse/services/interface-color";

export default class Logo extends Component {
  @service(() => InterfaceColorService) interfaceColor;

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
    {{#if (and @darkUrl (notEq @url @darkUrl))}}
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
