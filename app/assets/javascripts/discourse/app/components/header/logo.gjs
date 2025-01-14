import { and, eq, notEq } from "truth-helpers";
import getURL from "discourse/lib/get-url";

const Logo = <template>
  {{#if (and @darkUrl (notEq @url @darkUrl))}}
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

export default Logo;
