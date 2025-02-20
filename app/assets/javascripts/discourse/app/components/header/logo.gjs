import Component from "@glimmer/component";
import { service } from "@ember/service";
import { and, eq, notEq } from "truth-helpers";
import getURL from "discourse/lib/get-url";

export default class Logo extends Component {
  @service interfaceColor;

  <template>
    {{#if (and @darkUrl (notEq @url @darkUrl))}}
      <picture>
        <source
          srcset={{getURL @darkUrl}}
          media={{this.interfaceColor.darkMediaQuery}}
        />
        <img
          id="site-logo"
          class={{@key}}
          src={{getURL @url}}
          width={{if (eq @key "logo-small") "36"}}
          alt={{@title}}
        />
      </picture>
    {{else}}
      <img
        id="site-logo"
        class={{@key}}
        src={{getURL @url}}
        width={{if (eq @key "logo-small") "36"}}
        alt={{@title}}
      />
    {{/if}}
  </template>
}
