import { concat } from "@ember/helper";
import getURL from "discourse-common/lib/get-url";
import and from "truth-helpers/helpers/and";
import not from "truth-helpers/helpers/not";
import eq from "truth-helpers/helpers/eq";

const LogoElement = <template>
  {{#if (and @darkUrl (not (eq @url @darkUrl)))}}
    <picture>
      <source srcset={{getURL @darkUrl}} media="(prefers-color-scheme: dark)" />
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
</template>;

export default LogoElement;
